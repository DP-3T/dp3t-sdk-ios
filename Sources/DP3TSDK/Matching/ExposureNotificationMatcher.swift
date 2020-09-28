/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import ExposureNotification
import Foundation
import ZIPFoundation

class ExposureNotificationMatcher: Matcher {
    weak var timingManager: ExposureDetectionTimingManager?

    private let manager: ENManager

    private let exposureDayStorage: ExposureDayStorage

    private let logger = Logger(ExposureNotificationMatcher.self, category: "matcher")

    private let defaults: DefaultStorage

    private var progress: Progress?

    let synchronousQueue = DispatchQueue(label: "org.dpppt.matcher")

    init(manager: ENManager, exposureDayStorage: ExposureDayStorage, defaults: DefaultStorage = Default.shared) {
        self.manager = manager
        self.exposureDayStorage = exposureDayStorage
        self.defaults = defaults
    }

    func cancel() {
        progress?.cancel()
    }

    func receivedNewData(_ data: Data, now: Date = .init()) throws -> Bool {
        logger.trace()
        return try synchronousQueue.sync {
            var urls: [URL] = []
            let tempDirectory = FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent(UUID().uuidString)
            if let archive = Archive(data: data, accessMode: .read) {
                logger.debug("unarchived archive")
                for entry in archive {
                    let localURL = tempDirectory.appendingPathComponent(entry.path)
                    do {
                        _ = try archive.extract(entry, to: localURL)
                    } catch {
                        throw DP3TNetworkingError.couldNotParseData(error: error, origin: 1)
                    }
                    self.logger.debug("found %@ item in archive", entry.path)
                    urls.append(localURL)
                }
            }

            guard urls.isEmpty == false else { return false }

            let semaphore = DispatchSemaphore(value: 0)
            var exposureSummary: ENExposureDetectionSummary?
            var exposureDetectionError: Error? = DP3TTracingError.cancelled

            logger.log("calling detectExposures")
            progress = manager.detectExposures(configuration: .configuration, diagnosisKeyURLs: urls) { summary, error in
                exposureSummary = summary
                exposureDetectionError = error
            }
            
            // Wait for 3min and abort if detectExposures did not return in time
            if semaphore.wait(timeout: .now() + 180) == .timedOut {
                // This should never be the case but it protects us from errors
                // in ExposureNotifications.frameworks which cause the completion
                // handler to never get called.
                // If ENManager would return after 3min, the app gets kill before
                // that because we are only allowed to run for 2.5min in background
                logger.error("ENManager.detectExposures() failed to return in time")
            }

            if let error = exposureDetectionError {
                logger.error("ENManager.detectExposures failed error: %{public}@", error.localizedDescription)
                try? urls.forEach(deleteDiagnosisKeyFile(at:))
                throw DP3TTracingError.exposureNotificationError(error: error)
            }

            timingManager?.addDetection(timestamp: now)

            try? FileManager.default.removeItem(at: tempDirectory)

            guard let summary = exposureSummary else {
                assertionFailure("This should never happen, EN.detectExposure should either return a error or a summary")
                return false
            }

            guard !(progress?.isCancelled ?? false) else {
                throw DP3TTracingError.cancelled
            }

            var exposureWindows: [ENExposureWindow]?
            var exposureWindowsError: Error? = DP3TTracingError.cancelled
            progress = manager.getExposureWindows(summary: summary) { (windows, error) in
                exposureWindows = windows
                exposureWindowsError = error
                semaphore.signal()
            }

            // Wait for 3min and abort if getExposureWindows did not return in time
            if semaphore.wait(timeout: .now() + 180) == .timedOut {
                // This should never be the case but it protects us from errors
                // in ExposureNotifications.frameworks which cause the completion
                // handler to never get called.
                // If ENManager would return after 3min, the app gets kill before
                // that because we are only allowed to run for 2.5min in background
                logger.error("ENManager.getExposureWindows() failed to return in time")
            }

            if let error = exposureWindowsError {
                logger.error("ENManager.getExposureWindows failed error: %{public}@", error.localizedDescription)
                try? urls.forEach(deleteDiagnosisKeyFile(at:))
                throw DP3TTracingError.exposureNotificationError(error: error)
            }

            guard !(progress?.isCancelled ?? false) else {
                throw DP3TTracingError.cancelled
            }

            guard let windows = exposureWindows else {
                assertionFailure("This should never happen, EN.getExposureWindows should either return a error or windows")
                return false
            }

            
            let parameters = defaults.parameters.contactMatching
            let groups = windows.groupByDay
            let exposureDays = exposureDayStorage.getDays()
            for (day, windows) in groups {
                let attenuationValues = windows.attenuationValues(lowerThreshold: parameters.lowerThreshold,
                                                                  higherThreshold: parameters.higherThreshold)

                if attenuationValues.matches(factorLow: parameters.factorLow,
                                             factorHigh: parameters.factorHigh,
                                             triggerThreshold: parameters.triggerThreshold * 60) {
                    let day: ExposureDay = ExposureDay(identifier: UUID(), exposedDate: day, reportDate: Date(), isDeleted: false)
                    exposureDayStorage.add(day)

                }
            }

            if exposureDayStorage.getDays() != exposureDays {
                // a new exposure was found
                logger.log("finishing matching session with new exposure(s)")
                return true
            }

            logger.log("finishing matching session with no new exposures")
            return false
        }
    }

    func deleteDiagnosisKeyFile(at localURL: URL) throws {
        logger.trace()
        try FileManager.default.removeItem(at: localURL)
    }
}
