/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/**
 Synchronizes data on known cases for the time period of the past 14 days and stores them to the local database.

 Use a fresh instance for every synchronization call.
 */
class KnownCasesSynchronizer {
    /// The app id to use
    private let appInfo: DP3TApplicationInfo
    /// A database to store the known cases
    private let database: KnownCasesStorage

    // keep track of errors and successes with regard to individual requests (networking or database errors)
    private var errors = [(Date, DP3TTracingError)]()
    // a list of temporary known cases
    private var knownCases = [Date: [KnownCaseModel]]()

    // keep track of the number of issued and fulfilled requests
    private var numberOfIssuedRequests: Int = 0
    private var numberOfFulfilledRequests: Int = 0

    /// A DP3T matcher
    private weak var matcher: DP3TMatcherProtocol?

    /// Create a known case synchronizer
    /// - Parameters:
    ///   - appId: The app id to use
    ///   - database: The database for storage
    ///   - matcher: The matcher for DP3T resolution and checks
    init(appInfo: DP3TApplicationInfo, database: DP3TDatabase, matcher: DP3TMatcherProtocol) {
        self.appInfo = appInfo
        self.database = database.knownCasesStorage
        self.matcher = matcher
    }

    /// A callback result of async operations
    typealias Callback = (Result<Void, DP3TTracingError>) -> Void

    /// Synchronizes the local database with the remote one
    /// - Parameters:
    ///   - service: The service to use for synchronization
    ///   - callback: The callback once the task if finished
    func sync(service: ExposeeServiceClient, callback: Callback?) {
        // compute batch time stamps for the last 14 days
        let today = DayDate()
        let batchesPerDay = Int(TimeInterval.day) / NetworkingConstants.batchLenght
        let batchTimestamps = (0 ..< NetworkingConstants.daysToFetch).reversed().flatMap { days -> [Date] in
            let date = today.dayMin.addingTimeInterval(.day * Double(days) * -1)
            return (0 ..< batchesPerDay).map { batch in
                return date.addingTimeInterval(TimeInterval(batch * NetworkingConstants.batchLenght))
            }
        }

        for batchTimestamp in batchTimestamps {
            service.getExposee(batchTimestamp: batchTimestamp,
                               completion: dayResultHandler(batchTimestamp, callback: callback))
        }
    }

    /// Handle a single day
    /// - Parameters:
    ///   - dayIdentifier: The day identifier
    ///   - callback: The callback once the task is finished
    private func dayResultHandler(_ batchTimestamp: Date, callback: Callback?) -> (Result<[KnownCaseModel]?, DP3TTracingError>) -> Void {
        numberOfIssuedRequests += 1
        return { result in
            switch result {
            case let .failure(error):
                self.errors.append((batchTimestamp, error))
            case let .success(data):
                if let data = data {
                    self.knownCases[batchTimestamp] = data
                }
            }
            self.numberOfFulfilledRequests += 1
            self.checkForCompletion(callback: callback)
        }
    }

    /** Checks whether all issued requests have completed and then invokes the subsuming completion handler  */
    private func checkForCompletion(callback: Callback?) {
        guard numberOfFulfilledRequests == numberOfIssuedRequests else {
            return
        }

        /// If we encountered a timeInconsistency we return it
        func completeWithError(){
            if let tError = errors.first(where: {
                if case DP3TTracingError.timeInconsistency(shift: _) = $0.1 {
                    return true
                } else {
                    return false
                }
            }) {
                callback?(.failure(tError.1))
            } else {
                callback?(Result.failure(.caseSynchronizationError(errors: errors.map(\.1))))
            }
        }

        if errors.count == numberOfIssuedRequests { // all requests failed
            completeWithError()
        } else if errors.count > 0 { // some requests failed
            completeWithError()
        } else { // all requests were successful
            processDayResults(callback: callback)
        }

        errors.removeAll()
        knownCases.removeAll()
    }

    /** Process all received day data. */
    private func processDayResults(callback: Callback?) {
        // TODO: Handle db errors
        for (_, knownCases) in knownCases {
            try? database.update(knownCases: knownCases)
            for knownCase in knownCases {
                try? matcher?.checkNewKnownCase(knownCase)
            }
        }

        callback?(Result.success(()))
    }
}
