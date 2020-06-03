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

/**
 Synchronizes data on known cases
 */

class KnownCasesSynchronizer {
    private var defaults: DefaultStorage

    /// A DP3T matcher
    private weak var matcher: Matcher?

    private let descriptor: ApplicationDescriptor

    /// service client
    private weak var service: ExposeeServiceClientProtocol!

    private let logger = Logger(KnownCasesSynchronizer.self, category: "knownCasesSynchronizer")

    private let queue = DispatchQueue(label: "org.dpppt.sync")

    private var callbacks: [Callback] = []

    private var backgroundTask: UIBackgroundTaskIdentifier?

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
    typealias Callback = (Result<Void, DP3TTracingError>) -> Void

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
            if let backgroundTask = self.backgroundTask, backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                self.backgroundTask = .invalid
            }

            self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "org.dpppt.sync") { [weak self] in
                guard let self = self else { return }

                self.cancelSync()

                UIApplication.shared.endBackgroundTask(self.backgroundTask!)
                self.backgroundTask = .invalid
            }

            self.internalSync(now: now) { [weak self] result in
                guard let self = self else { return }
                self.queue.async {
                    UIApplication.shared.endBackgroundTask(self.backgroundTask!)
                    self.backgroundTask = .invalid
                    self.callbacks.forEach { $0(result) }
                    self.callbacks.removeAll()
                }
            }
        }
    }

    func cancelSync() {
        queue.sync { [weak self] in
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

        var occuredError: DP3TTracingError?

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
                logger.log("skipping %{public}@ since the last check was at %{public}@ next sync allowed after: %{public}@", currentKeyDate.description, lastSync.description, lastSync.description)
                continue
            }

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
                        occuredError = .networkingError(error: error)
                    case let .success(knownCasesData):
                        do {
                            if let data = knownCasesData.data {
                                self.logger.log("received data(%{public}d bytes) for %{public}@", data.count, currentKeyDate.description)
                                try self.matcher?.receivedNewKnownCaseData(data, keyDate: currentKeyDate)
                            } else {
                                self.logger.log("received no data for %{public}@", currentKeyDate.description)
                            }

                            lastSyncStore[currentKeyDate] = now

                        } catch let error as DP3TNetworkingError {
                            self.logger.error("matcher receive error: %{public}@", error.localizedDescription)

                            occuredError = .networkingError(error: error)
                        } catch {
                            self.logger.error("matcher receive error: %{public}@", error.localizedDescription)

                            occuredError = .networkingError(error: .couldNotParseData(error: error, origin: 0))
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

            guard self.isCancelled == false else {
                callback?(.failure(.cancelled))
                return
            }

            do {
                try self.matcher?.finalizeMatchingSession(now: now)
            } catch {
                self.logger.error("matcher finalize error: %{public}@", error.localizedDescription)
                occuredError = .exposureNotificationError(error: error)
            }

            if let error = occuredError {
                self.logger.error("finishing sync with error: %{public}@", error.localizedDescription)
                callback?(.failure(error))
            } else {
                self.logger.log("finishing sync successful")
                self.defaults.lastSyncTimestamps = lastSyncStore
                callback?(.success(()))
            }
        }
    }
}
