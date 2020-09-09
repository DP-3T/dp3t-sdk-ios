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

    private var dataTasks: [URLSessionDataTask] = []

    private var isCancelled: Bool = false

    private var tasksRunning: Int = 0

    private let dispatchGroup = DispatchGroup()

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

            for task in self.dataTasks {
                task.cancel()
            }
            self.dataTasks.removeAll()

            for _ in 0 ..< self.tasksRunning {
                self.dispatchGroup.leave()
            }
            self.tasksRunning = 0
        }
    }

    private func internalSync(now: Date = Date(), callback: Callback?) {
        logger.trace()

        isCancelled = false

        let todayDate = DayDate(date: now).dayMin

        let minimumDate = todayDate.addingTimeInterval(-.day * Double(defaults.parameters.networking.daysToCheck - 1))

        var calendar = Calendar.current
        calendar.timeZone = Default.shared.parameters.crypto.timeZone
        let components = calendar.dateComponents([.day], from: minimumDate, to: todayDate)

        let daysToFetch = components.day ?? 0

        // cleanup old published after

        var lastSyncStore = defaults.lastSyncTimestamps
        for date in lastSyncStore.keys {
            if date < minimumDate {
                lastSyncStore.removeValue(forKey: date)
            }
        }

        var occuredErrors: [DP3TTracingError] = []
        var totalNumberOfRequests: Int = 0

        var matchfound: Bool = false

        for day in 0 ... daysToFetch {
            guard let currentKeyDate = calendar.date(byAdding: .day, value: day, to: minimumDate) else {
                continue
            }

            // To avoid syncing more than 2 times a day, we set the value of last sync to the desired hour minus 1 millisecond
            guard let preferredHour = Calendar.current.date(bySettingHour: defaults.parameters.networking.syncHourMorning, minute: 0, second: 0, of: now),
                let initialHour = Calendar.current.date(byAdding: .nanosecond, value: -1000, to: preferredHour) else {
                fatalError()
            }

            let lastSync = lastSyncStore[currentKeyDate] ?? initialHour

            guard descriptor.mode == .test || timingManager.shouldDetect(lastDetection: lastSync, now: now) else {
                logger.log("skipping %{public}@ since shouldDetect returned false", currentKeyDate.description)
                continue
            }

            totalNumberOfRequests += 1
            dispatchGroup.enter()
            tasksRunning += 1
            let task = service.getExposee(batchTimestamp: currentKeyDate) { [weak self] result in
                guard let self = self else { return }
                self.queue.sync {
                    guard self.isCancelled == false else {
                        return
                    }
                    switch result {
                    case let .failure(error):
                        occuredErrors.append(.networkingError(error: error))
                    case let .success(knownCasesData):
                        do {
                            if let data = knownCasesData.data {
                                if let matcher = self.matcher {
                                    self.logger.log("received data(%{public}d bytes) for %{public}@", data.count, currentKeyDate.description)
                                    let foundNewMatch = try matcher.receivedNewData(data, now: now)
                                    matchfound = matchfound || foundNewMatch
                                }else {
                                    self.logger.error("matcher not present")
                                }
                            } else {
                                self.logger.log("received no data for %{public}@", currentKeyDate.description)
                            }

                            lastSyncStore[currentKeyDate] = now

                        } catch let error as DP3TNetworkingError {
                            self.logger.error("matcher receive error: %{public}@", error.localizedDescription)
                            occuredErrors.append(.networkingError(error: error))
                        } catch let error as DP3TTracingError {
                            self.logger.error("matcher receive error: %{public}@", error.localizedDescription)
                            occuredErrors.append(error)
                        } catch {
                            self.logger.error("matcher receive error: %{public}@", error.localizedDescription)
                            occuredErrors.append(.caseSynchronizationError(errors: [error]))
                        }
                    }
                    self.dispatchGroup.leave()
                    self.tasksRunning -= 1
                }
            }
            dataTasks.append(task)
        }

        dataTasks.forEach { $0.resume() }

        dispatchGroup.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }

            self.dataTasks.removeAll()

            if matchfound {
                self.delegate?.didFindMatch()
            }

            guard self.isCancelled == false else {
                callback?(.failure(.cancelled))
                self.logger.error("sync got cancelled")
                return
            }

            self.defaults.lastSyncTimestamps = lastSyncStore

            if let lastError = occuredErrors.last {
                self.logger.error("finishing sync with error: %{public}@", lastError.localizedDescription)
                callback?(.failure(lastError))
            } else {
                self.logger.log("finishing sync successful")
                if totalNumberOfRequests != 0 {
                    callback?(.success)
                } else {
                    callback?(.skipped)
                }
            }
            
            DP3TTracing.activityDelegate?.syncCompleted(totalRequest: totalNumberOfRequests, errors: occuredErrors)
        }
    }
}
