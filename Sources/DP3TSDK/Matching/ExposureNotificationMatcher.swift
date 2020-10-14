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

enum ExposureNotificationMatcherError: Error {
    case timeOut
}

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
            let tempDirectory = getTempDirectory()

            let urls: [URL] = try unarchiveData(data, into: tempDirectory)

            guard urls.isEmpty == false else { return false }

            let detectionResult = detectExposure(urls: urls)

            timingManager?.addDetection(timestamp: now)

            try? FileManager.default.removeItem(at: tempDirectory)

            let summary: ENExposureDetectionSummary
            switch detectionResult {
            case let .failure(error):
                logger.error("ENManager.detectExposures failed error: %{public}@", error.localizedDescription)
                throw DP3TTracingError.exposureNotificationError(error: error)
            case let .success(value):
                logger.log("received summary: %{public}@", value.description)
                summary = value
            }

            guard !(progress?.isCancelled ?? false) else {
                throw DP3TTracingError.cancelled
            }

            let windowsResult = getExposureWindows(summary: summary)
            let windows: [ENExposureWindow]
            switch windowsResult {
            case let .failure(error):
                logger.error("ENManager.getExposureWindows failed error: %{public}@", error.localizedDescription)
                throw DP3TTracingError.exposureNotificationError(error: error)
            case let .success(value):
                logger.log("received windows: %{public}@", value.description)
                windows = value
            }

            guard !(progress?.isCancelled ?? false) else {
                throw DP3TTracingError.cancelled
            }

            let exposureDays = exposureDayStorage.getDays()

            updateExposureDays(with: windows, now: now)

            if exposureDayStorage.getDays() != exposureDays {
                // a new exposure was found
                logger.log("finishing matching session with new exposure(s)")
                return true
            }

            logger.log("finishing matching session with no new exposures")
            return false
        }
    }

    private func updateExposureDays(with windows: [ENExposureWindow], now: Date) {
        dispatchPrecondition(condition: .onQueue(synchronousQueue))
        
        let parameters = defaults.parameters.contactMatching
        let groups = windows.groupByDay
        for (day, windows) in groups {
            guard now.timeIntervalSince(day) < defaults.parameters.contactMatching.notificationGenerationTimeSpan else {
                continue
            }
            let attenuationValues = windows.attenuationValues(lowerThreshold: parameters.lowerThreshold,
                                                              higherThreshold: parameters.higherThreshold)

            if attenuationValues.matches(factorLow: parameters.factorLow,
                                         factorHigh: parameters.factorHigh,
                                         triggerThreshold: parameters.triggerThreshold * 60) {
                let day: ExposureDay = ExposureDay(identifier: UUID(), exposedDate: day, reportDate: Date(), isDeleted: false)
                exposureDayStorage.add(day)

            }
        }
    }

    private func unarchiveData(_ data: Data, into tempDirectory: URL) throws -> [URL] {
        logger.trace()
        dispatchPrecondition(condition: .onQueue(synchronousQueue))

        var urls: [URL] = []

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
        return urls
    }

    typealias DetectionResult = Result<ENExposureDetectionSummary, Error>
    private func detectExposure(urls: [URL]) -> DetectionResult {
        logger.trace()
        dispatchPrecondition(condition: .onQueue(synchronousQueue))

        let semaphore = DispatchSemaphore(value: 0)
        var exposureSummary: ENExposureDetectionSummary?
        var exposureDetectionError: Error? = DP3TTracingError.cancelled

        logger.log("calling detectExposures")
        progress = manager.detectExposures(configuration: .configuration, diagnosisKeyURLs: urls) { summary, error in
            exposureSummary = summary
            exposureDetectionError = error
            semaphore.signal()
        }

        // Wait for 3min and abort if detectExposures did not return in time
        if semaphore.wait(timeout: .now() + 180) == .timedOut {
            // This should never be the case but it protects us from errors
            // in ExposureNotifications.frameworks which cause the completion
            // handler to never get called.
            // If ENManager would return after 3min, the app gets kill before
            // that because we are only allowed to run for 2.5min in background
            logger.error("ENManager.detectExposures() failed to return in time")
            return .failure(ExposureNotificationMatcherError.timeOut)
        }

        if let error = exposureDetectionError {
            return .failure(error)
        } else if let summary = exposureSummary {
            return .success(summary)
        }
        fatalError("This should never happen, EN.detectExposure should either return a error or a summary")
    }

    typealias WindowsResult = Result<[ENExposureWindow], Error>
    private func getExposureWindows(summary: ENExposureDetectionSummary) -> WindowsResult {
        logger.trace()
        dispatchPrecondition(condition: .onQueue(synchronousQueue))

        let semaphore = DispatchSemaphore(value: 0)
        var exposureWindows: [ENExposureWindow]?
        var exposureWindowsError: Error? = DP3TTracingError.cancelled
        logger.log("calling getExposureWindows")
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
            return .failure(ExposureNotificationMatcherError.timeOut)
        }

        if let error = exposureWindowsError {
            return .failure(error)
        } else if let windows = exposureWindows {
            return .success(windows)
        }
        fatalError("This should never happen, EN.getExposureWindows should either return a error or windows")
    }

    private func getTempDirectory() -> URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(UUID().uuidString)
    }
}
