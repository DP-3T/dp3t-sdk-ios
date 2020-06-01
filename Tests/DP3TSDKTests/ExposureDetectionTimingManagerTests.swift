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

class MockExposureDetectionTimingManager: ExposureDetectionTimingManager {
    var nowTs: Date = .init()

    override var now: Date {
        nowTs
    }
}

class ExposureDetectionTimingManagerTests: XCTestCase {
    func testAfter20Calls() {
        let defaults = MockDefaults()
        let manager = MockExposureDetectionTimingManager(storage: defaults)
        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -Double(20 - i) * .hour))
        }

        XCTAssertEqual(manager.remainingDetections, 0)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day)), false)
    }

    func testRemainingInitial() {
        let defaults = MockDefaults()
        let manager = MockExposureDetectionTimingManager(storage: defaults)
        XCTAssertEqual(manager.remainingDetections, MockExposureDetectionTimingManager.maxDetections)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day)), true)
    }

    func testRemainingAfterFirst() {
        let defaults = MockDefaults()
        let manager = MockExposureDetectionTimingManager(storage: defaults)
        manager.addDetection()
        XCTAssertEqual(manager.remainingDetections, MockExposureDetectionTimingManager.maxDetections - 1)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day)), true)
    }

    func testRemainginAfter1Day() {
        let defaults = MockDefaults()
        let manager = MockExposureDetectionTimingManager(storage: defaults)
        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -.day - Double(20 - i) * .hour))
        }
        XCTAssertEqual(manager.remainingDetections, MockExposureDetectionTimingManager.maxDetections)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day)), true)
    }

    func testCleanup() {
        let defaults = MockDefaults()
        let manager = MockExposureDetectionTimingManager(storage: defaults)
        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -.day - Double(20 - i) * .hour))
        }
        manager.nowTs = Date(timeIntervalSinceNow: 2 * .day)
        _ = manager.remainingDetections
        XCTAssertEqual(defaults.exposureDetectionDates.count, 0)
    }

    func testAfterCleanup() {
        let defaults = MockDefaults()
        let manager = MockExposureDetectionTimingManager(storage: defaults)
        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -.day - Double(20 - i) * .hour))
        }
        manager.nowTs = Date(timeIntervalSinceNow: 2 * .day)
        _ = manager.remainingDetections

        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeInterval: -.day - Double(20 - i) * .hour, since: manager.nowTs))
        }
        XCTAssertEqual(manager.remainingDetections, MockExposureDetectionTimingManager.maxDetections)
        XCTAssertEqual(manager.shouldDetect(lastDetection: .init(timeIntervalSinceNow: -.day)), true)
    }

    func testLastDesiredSyncTimeNoon() {
        let defaults = MockDefaults()
        let manager = MockExposureDetectionTimingManager(storage: defaults)
        manager.nowTs = Self.formatter.date(from: "19.05.2020 12:12")!

        let output = Self.formatter.date(from: "19.05.2020 0\(defaults.parameters.networking.syncHourMorning):00")!
        XCTAssertEqual(manager.lastDesiredSyncTime, output)
    }

    func testLastDesiredSyncTimeYesterday() {
        let defaults = MockDefaults()
        let manager = MockExposureDetectionTimingManager(storage: defaults)
        manager.nowTs = Self.formatter.date(from: "19.05.2020 05:55")!

        let output = Self.formatter.date(from: "18.05.2020 \(defaults.parameters.networking.syncHourEvening):00")!
        XCTAssertEqual(manager.lastDesiredSyncTime, output)
    }

    func testLastDesiredSyncTimeNight() {
        let defaults = MockDefaults()
        let manager = MockExposureDetectionTimingManager(storage: defaults)
        manager.nowTs = Self.formatter.date(from: "19.05.2020 23:55")!

        let output = Self.formatter.date(from: "19.05.2020 \(defaults.parameters.networking.syncHourEvening):00")!
        XCTAssertEqual(manager.lastDesiredSyncTime, output)
    }

    static var formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy HH:mm"
        return df
    }()
}
