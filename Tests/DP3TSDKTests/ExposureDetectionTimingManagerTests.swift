/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

@testable import DP3TSDK
import Foundation
import XCTest

class ExposureDetectionTimingManagerTests: XCTestCase {
    func testAfter20Calls() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -Double(20 - i) * .hour))
        }

        XCTAssertEqual(manager.getRemainingDetections(), 0)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day)), false)
    }

    func testRemainingInitial() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        XCTAssertEqual(manager.getRemainingDetections(), ExposureDetectionTimingManager.maxDetections)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day)), true)
    }

    func testRemainingAfterFirst() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        manager.addDetection()
        XCTAssertEqual(manager.getRemainingDetections(), ExposureDetectionTimingManager.maxDetections - 1)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day)), true)
    }

    func testRemainginAfter1Day() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -.day - Double(20 - i) * .hour))
        }
        XCTAssertEqual(manager.getRemainingDetections(), ExposureDetectionTimingManager.maxDetections)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day)), true)
    }

    func testCleanup() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -.day - Double(20 - i) * .hour))
        }
        _ = manager.getRemainingDetections(now: Date(timeIntervalSinceNow: 2 * .day))
        XCTAssertEqual(defaults.exposureDetectionDates.count, 0)
    }

    func testAfterCleanup() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -.day - Double(20 - i) * .hour))
        }
        let now = Date(timeIntervalSinceNow: 2 * .day)
        _ = manager.getRemainingDetections(now: now)

        for i in 0 ... 19 {
            manager.addDetection(timestamp: .init(timeInterval: -.day - Double(20 - i) * .hour, since: now))
        }
        XCTAssertEqual(manager.getRemainingDetections(now: now), ExposureDetectionTimingManager.maxDetections)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day), now: now), true)
    }

    func testLastDesiredSyncTimeNoon() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)

        let output = Self.formatter.date(from: "19.05.2020 0\(defaults.parameters.networking.syncHourMorning):00")!
        XCTAssertEqual(manager.getLastDesiredSyncTime(now: Self.formatter.date(from: "19.05.2020 12:12")!), output)
    }

    func testLastDesiredSyncTimeYesterday() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)

        let output = Self.formatter.date(from: "18.05.2020 \(defaults.parameters.networking.syncHourEvening):00")!
        XCTAssertEqual(manager.getLastDesiredSyncTime(now: Self.formatter.date(from: "19.05.2020 05:55")!), output)
    }

    func testLastDesiredSyncTimeNight() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)

        let output = Self.formatter.date(from: "19.05.2020 \(defaults.parameters.networking.syncHourEvening):00")!
        XCTAssertEqual(manager.getLastDesiredSyncTime(now: Self.formatter.date(from: "19.05.2020 23:55")!), output)
    }

    static var formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy HH:mm"
        return df
    }()
}
