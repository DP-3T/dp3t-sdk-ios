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
    var storage: DefaultStorage

    static let maxDetections = 20

    init(storage: DefaultStorage = Default.shared) {
        self.storage = storage
    }

    func shouldDetect(lastDetection: Date, now: Date = .init()) -> Bool {
        return getRemainingDetections(now: now) != 0 && lastDetection < getLastDesiredSyncTime(now: now)
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


    func getLastDesiredSyncTime(now: Date = .init()) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.hour, .day, .month, .year], from: now)
        if dateComponents.hour! < storage.parameters.networking.syncHourMorning {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            return calendar.date(bySettingHour: storage.parameters.networking.syncHourEvening, minute: 0, second: 0, of: yesterday)!
        } else if dateComponents.hour! < storage.parameters.networking.syncHourEvening {
            return calendar.date(bySettingHour: storage.parameters.networking.syncHourMorning, minute: 0, second: 0, of: now)!
        } else {
            return calendar.date(bySettingHour: storage.parameters.networking.syncHourEvening, minute: 0, second: 0, of: now)!
        }
    }
}
