/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation
import UIKit.UIApplication

/// A delegate used to respond on DP3T events
protocol KnownCasesSynchronizerDelegate: class {
    /// We found a match
    func didFindMatch()
}

/**
 Synchronizes data on known cases
 */

class KnownCasesSynchronizer {
    private var defaults: DefaultStorage

    /// A DP3T matcher
    private weak var matcher: Matcher?

    weak var delegate: KnownCasesSynchronizerDelegate?

    private let descriptor: ApplicationDescriptor

    /// service client
    private weak var service: ExposeeServiceClientProtocol!

    private let logger = Logger(KnownCasesSynchronizer.self, category: "knownCasesSynchronizer")

    private let queue = DispatchQueue(label: "org.dpppt.sync")

    private var callbacks: [Callback] = []

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private var dataTask: URLSessionDataTask?

    private var isCancelled: Bool = false

    private let timingManager: ExposureDetectionTimingManager

    /// Create a known case synchronizer
    /// - Parameters:
    ///   - matcher: The matcher for DP3T resolution and checks
    init(matcher: Matcher,
         service: ExposeeServiceClientProtocol,
         defaults: DefaultStorage = Default.shared,
         descriptor: ApplicationDescriptor) {
        self.matcher = matcher
        self.defaults = defaults
        self.service = service
        self.descriptor = descriptor
        timingManager = .init(storage: defaults)
        matcher.timingManager = timingManager
    }

    /// A callback result of async operations
    typealias Callback = (SyncResult) -> Void

    /// Synchronizes the local database with the remote one
    /// - Parameters:
    ///   - service: The service to use for synchronization
    ///   - callback: The callback once the task if finished
    func sync(now: Date = Date(), callback: @escaping Callback) {
        logger.trace()

        queue.async { [weak self] in
            guard let self = self else { return }

            guard self.callbacks.isEmpty else {
                self.callbacks.append(callback)
                return
            }

            self.callbacks.append(callback)

            // If we already have a background task we need to cancel it
            if self.backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }

            self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "org.dpppt.sync") { [weak self] in
                guard let self = self else { return }
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }

            self.internalSync(now: now) { [weak self] result in
                guard let self = self else { return }
                self.queue.async {
                    UIApplication.shared.endBackgroundTask(self.backgroundTask)
                    self.backgroundTask = .invalid
                    self.callbacks.forEach { $0(result) }
                    self.callbacks.removeAll()
                }
            }
        }
    }

    func cancelSync() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isCancelled = true
            self.dataTask?.cancel()
            self.dataTask = nil
            self.matcher?.cancel()
        }
    }

    private func internalSync(now: Date = Date(), callback: Callback?) {
        logger.trace()
        isCancelled = false

        let lastKeyBundleTag = defaults.lastKeyBundleTag

        guard descriptor.mode == .test || timingManager.shouldDetect(now: now) else {
            logger.log("skipping sync since shouldDetect returned false")
            callback?(.skipped)
            return
        }

        dataTask = service.getExposee(lastKeyBundleTag: lastKeyBundleTag, includeInternationalKeys: defaults.includeInternationalKeys) { [weak self] (result) in
            guard let self = self else { return }
            guard self.isCancelled == false else {
                return
            }
            switch result {
            case let .success(knownCasesData):
                do {
                    if let data = knownCasesData.data {
                        if let matcher = self.matcher {
                            self.logger.log("received data(%{public}d bytes) [since: %{public}@]", data.count, lastKeyBundleTag?.description ?? "nil")
                            let foundNewMatch = try matcher.receivedNewData(data, now: now)
                            if foundNewMatch {
                                self.delegate?.didFindMatch()
                            }
                        }else {
                            self.logger.error("matcher not present")
                        }
                    } else {
                        self.logger.log("received no data [since: %{public}@]", lastKeyBundleTag?.description ?? "nil")
                    }

                    if let publishedKeyTag = knownCasesData.keyBundleTag {
                        self.logger.log("storing new since: %{public}@", publishedKeyTag.description)
                        self.defaults.lastKeyBundleTag = publishedKeyTag
                    }

                    DP3TTracing.activityDelegate?.syncCompleted(totalRequest: 1, errors: [])

                    callback?(.success)
                } catch let error as DP3TNetworkingError {
                    self.logger.error("matcher receive error: %{public}@", error.localizedDescription)
                    DP3TTracing.activityDelegate?.syncCompleted(totalRequest: 1, errors: [.networkingError(error: error)])
                    callback?(.failure(.networkingError(error: error)))
                } catch let error as DP3TTracingError {
                    self.logger.error("matcher receive error: %{public}@", error.localizedDescription)
                    DP3TTracing.activityDelegate?.syncCompleted(totalRequest: 1, errors: [error])
                    callback?(.failure(error))
                } catch {
                    self.logger.error("matcher receive error: %{public}@", error.localizedDescription)
                    DP3TTracing.activityDelegate?.syncCompleted(totalRequest: 1, errors: [.caseSynchronizationError(errors: [error])])
                    callback?(.failure(.caseSynchronizationError(errors: [error])))
                }
            case let .failure(error):
                self.logger.error("could not get exposeeList from backend: %{public}@", error.localizedDescription)
                DP3TTracing.activityDelegate?.syncCompleted(totalRequest: 1, errors: [.networkingError(error: error)])
                callback?(.failure(.networkingError(error: error)))
            }
        }
        dataTask?.resume()
    }
}
