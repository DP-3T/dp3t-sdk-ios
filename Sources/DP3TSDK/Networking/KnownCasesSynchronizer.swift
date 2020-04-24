/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/**
 Synchronizes data on known cases
 */
class KnownCasesSynchronizer {
    /// The app id to use
    private let appInfo: DP3TApplicationInfo
    /// A database to store the known cases
    private let database: KnownCasesStorage

    private var defaults: DefaultStorage

    /// A DP3T matcher
    private weak var matcher: DP3TMatcherProtocol?

    /// Create a known case synchronizer
    /// - Parameters:
    ///   - appId: The app id to use
    ///   - database: The database for storage
    ///   - matcher: The matcher for DP3T resolution and checks
    init(appInfo: DP3TApplicationInfo,
         database: DP3TDatabase,
         matcher: DP3TMatcherProtocol,
         defaults: DefaultStorage = Default.shared) {
        self.appInfo = appInfo
        self.database = database.knownCasesStorage
        self.matcher = matcher
        self.defaults = defaults
    }

    /// A callback result of async operations
    typealias Callback = (Result<Void, DP3TTracingError>) -> Void

    /// Synchronizes the local database with the remote one
    /// - Parameters:
    ///   - service: The service to use for synchronization
    ///   - callback: The callback once the task if finished
    /// - Returns: the operation which can be used to cancel the sync
    @discardableResult
    func sync(service: ExposeeServiceClient, callback: Callback?) -> Operation {
        let queue = OperationQueue()

        let operation = BlockOperation {
            self.internalSync(service: service, callback: callback)
        }

        queue.addOperation(operation)

        return operation
    }

    private func internalSync(service: ExposeeServiceClient, callback: Callback?){
        let now = Date().timeIntervalSince1970
        let currentBucketEnd = now - now.truncatingRemainder(dividingBy: NetworkingConstants.batchLenght)

        var nextBatch: TimeInterval!
        if let lastBatch = defaults.lastLoadedBatchReleaseTime,
            lastBatch < Date(){
            nextBatch = lastBatch.timeIntervalSince1970
        } else {
            nextBatch = now - now.truncatingRemainder(dividingBy: NetworkingConstants.batchLenght)
        }

        let batchesToLoad = Int((now - nextBatch) / NetworkingConstants.batchLenght)

        nextBatch += NetworkingConstants.batchLenght

        for batchIndex in (0 ..< batchesToLoad) {
            let currentReleaseTime = Date(timeIntervalSince1970: nextBatch + NetworkingConstants.batchLenght * TimeInterval(batchIndex))
            let result = service.getExposeeSynchronously(batchTimestamp: currentReleaseTime)
            switch result {
            case let .failure(error):
                callback?(.failure(error))
                return
            case let .success(knownCases):
                if let knownCases = knownCases {
                    try? database.update(knownCases: knownCases)
                    for knownCase in knownCases {
                        try? matcher?.checkNewKnownCase(knownCase)
                    }
                }
                defaults.lastLoadedBatchReleaseTime = currentReleaseTime
            }
        }

        callback?(.success(()))
    }
}
