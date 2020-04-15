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
    private let appId: String
    /// A database to store the known cases
    private let database: KnownCasesStorage

    // keep track of errors and successes with regard to individual requests (networking or database errors)
    private var errors = [(String, Error)]()
    // a list of temporary known cases
    private var knownCases = [String: [KnownCaseModel]]()

    // keep track of the number of issued and fulfilled requests
    private var numberOfIssuedRequests: Int = 0
    private var numberOfFulfilledRequests: Int = 0

    /// A DP3T matcher
    private weak var matcher: DP3TMatcher?

    /// Create a known case synchronizer
    /// - Parameters:
    ///   - appId: The app id to use
    ///   - database: The database for storage
    ///   - matcher: The matcher for DP3T resolution and checks
    init(appId: String, database: DP3TDatabase, matcher: DP3TMatcher) {
        self.appId = appId
        self.database = database.knownCasesStorage
        self.matcher = matcher
    }

    /// A callback result of async operations
    typealias Callback = (Result<Void, DP3TTracingErrors>) -> Void

    /// Synchronizes the local database with the remote one
    /// - Parameters:
    ///   - service: The service to use for synchronization
    ///   - callback: The callback once the task if finished
    func sync(service: ExposeeServiceClient, callback: Callback?) {
        errors.removeAll()
        knownCases.removeAll()
        // compute day identifiers (formatted dates) for the last 14 days
        let dayIdentifierFormatter = DateFormatter()
        dayIdentifierFormatter.dateFormat = "yyyy-MM-dd"
        let dayIdentifiers = (0 ..< 14).reversed().map { days -> String in
            let date = Calendar.current.date(byAdding: .day, value: -1 * days, to: Date())!
            return dayIdentifierFormatter.string(from: date)
        }

        for dayIdentifier in dayIdentifiers {
            service.getExposee(dayIdentifier: dayIdentifier,
                               completion: dayResultHandler(dayIdentifier, callback: callback))
        }
    }

    /// Handle a single day
    /// - Parameters:
    ///   - dayIdentifier: The day identifier
    ///   - callback: The callback once the task is finished
    private func dayResultHandler(_ dayIdentifier: String, callback: Callback?) -> (Result<[KnownCaseModel]?, DP3TTracingErrors>) -> Void {
        numberOfIssuedRequests += 1
        return { result in
            switch result {
            case let .failure(error):
                self.errors.append((dayIdentifier, error))
            case let .success(data):
                if let data = data {
                    self.knownCases[dayIdentifier] = data
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

        if errors.count == numberOfIssuedRequests { // all requests failed
            callback?(Result.failure(.CaseSynchronizationError))
        } else if errors.count > 0 { // some requests failed
            callback?(Result.failure(.CaseSynchronizationError))
        } else { // all requests were successful
            processDayResults(callback: callback)
        }
    }

    /** Process all received day data. */
    private func processDayResults(callback: Callback?) {
        // TODO: Handle db errors
        for (day, knownCases) in knownCases {
            try? database.update(knownCases: knownCases, day: day)
            for knownCase in knownCases {
                try? matcher?.checkNewKnownCase(knownCase, bucketDay: day)
            }
        }

        callback?(Result.success(()))
    }
}
