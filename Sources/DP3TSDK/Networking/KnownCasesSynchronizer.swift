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
    private var defaults: DefaultStorage

    /// A DP3T matcher
    private weak var matcher: Matcher?

    /// service client
    private weak var service: ExposeeServiceClient!

    private let log = Logger(DP3TDatabase.self, category: "knownCasesSynchronizer")

    /// Create a known case synchronizer
    /// - Parameters:
    ///   - matcher: The matcher for DP3T resolution and checks
    init(matcher: Matcher,
         service: ExposeeServiceClient,
         defaults: DefaultStorage = Default.shared) {
        self.matcher = matcher
        self.defaults = defaults
        self.service = service
    }

    /// A callback result of async operations
    typealias Callback = (Result<Void, DP3TNetworkingError>) -> Void

    /// Synchronizes the local database with the remote one
    /// - Parameters:
    ///   - service: The service to use for synchronization
    ///   - callback: The callback once the task if finished
    /// - Returns: the operation which can be used to cancel the sync
    @discardableResult
    func sync(now: Date = Date(), callback: Callback?) -> Operation {
        log.trace()
        let queue = OperationQueue()

        let operation = BlockOperation {
            self.internalSync(now: now, callback: callback)
        }

        queue.addOperation(operation)

        return operation
    }

    /// Stores the first SDK launch date
    @discardableResult
    static func initializeSynchronizerIfNeeded(defaults: DefaultStorage = Default.shared) -> Date {
        guard defaults.lastLoadedBatchReleaseTime == nil else { return defaults.lastLoadedBatchReleaseTime! }
        let nowTimestamp = Date().timeIntervalSince1970
        let lastBatch = Date(timeIntervalSince1970: nowTimestamp - nowTimestamp.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength))
        var mutableDefaults = defaults
        mutableDefaults.lastLoadedBatchReleaseTime = lastBatch
        return lastBatch
    }

    private func internalSync(now: Date = Date(), callback: Callback?) {
        log.trace()
        let nowTimestamp = now.timeIntervalSince1970

        var lastBatch: TimeInterval!
        if let storedLastBatch = defaults.lastLoadedBatchReleaseTime,
            storedLastBatch < Date() {
            lastBatch = storedLastBatch.timeIntervalSince1970
        } else {
            assert(false, "This should never happen if initializeSynchronizerIfNeeded gets called on SDK init")
            lastBatch = KnownCasesSynchronizer.initializeSynchronizerIfNeeded().timeIntervalSince1970
        }

        lastBatch -= 5 * .day

        let batchesToLoad = Int((nowTimestamp - lastBatch) / Default.shared.parameters.networking.batchLength)

        let nextBatch = lastBatch + Default.shared.parameters.networking.batchLength

        for batchIndex in 0 ..< batchesToLoad {
            let currentReleaseTime = Date(timeIntervalSince1970: nextBatch + Default.shared.parameters.networking.batchLength * TimeInterval(batchIndex))
            let result = service.getExposeeSynchronously(batchTimestamp: currentReleaseTime)
            switch result {
            case let .failure(error):
                callback?(.failure(error))
                return
            case let .success(knownCasesData):
                do {
                    if let data = knownCasesData {
                        try matcher?.receivedNewKnownCaseData(data, batchTimestamp: currentReleaseTime)
                    }
                } catch let error as DP3TNetworkingError {
                    log.error("matcher receive error: %@", error.localizedDescription)
                    callback?(.failure(error))
                    return
                } catch {
                    log.error("matcher receive error: %@", error.localizedDescription)
                    callback?(.failure(.couldNotParseData(error: error, origin: 0)))
                }
                defaults.lastLoadedBatchReleaseTime = currentReleaseTime
            }
        }

        do {
            try matcher?.finalizeMatchingSession()
        } catch {
            log.error("matcher finalize error: %@", error.localizedDescription)
            // set last batch to initial value if a error happend
            defaults.lastLoadedBatchReleaseTime = Date(timeIntervalSince1970: lastBatch)
            callback?(.failure(.couldNotParseData(error: error, origin: 0)))
            return
        }

        callback?(.success(()))
    }
}
