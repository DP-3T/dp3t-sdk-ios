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

class ExposureDetectionTimingManager {
    private var storage: DefaultStorage

    private let logger = Logger(ExposureDetectionTimingManager.self, category: "exposureDetectionTimingManager")

    static let maxDetections = 6

    private var minTimeintervalBetweenChecks: TimeInterval {
        .day / TimeInterval(Self.maxDetections)
    }

    init(storage: DefaultStorage = Default.shared) {
        self.storage = storage
    }

    func shouldDetect(now: Date = .init()) -> Bool {
        if getRemainingDetections(now: now) == 0 {
            logger.log("no detections remaining for today")
            return false
        }
        if timeIntervalSinceLatestDetection(now: now) < minTimeintervalBetweenChecks {
            logger.log("timeIntervalSinceLatestDetection too small")
            return false
        }
        return true
    }

    func addDetection(timestamp: Date = .init()) {
        storage.exposureDetectionDates.append(timestamp)
    }

    func getRemainingDetections(now: Date = .init()) -> Int {
        defer {
            storage.exposureDetectionDates = storage.exposureDetectionDates.filter {
                abs($0.timeIntervalSince(now)) < .day
            }
        }

        let beginningOfCurrentWindow: Date = now - .day

        let allDetections = storage.exposureDetectionDates

        let inCurrentWindow = allDetections.filter { $0 >= beginningOfCurrentWindow }

        return max(Self.maxDetections - inCurrentWindow.count, 0)
    }

    func timeIntervalSinceLatestDetection(now: Date = .init()) -> TimeInterval {
        guard let latest = storage.exposureDetectionDates.max(by: <) else {
            return .infinity
        }
        return now.timeIntervalSince(latest)
    }
}
