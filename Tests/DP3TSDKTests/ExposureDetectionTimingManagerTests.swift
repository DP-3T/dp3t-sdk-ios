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
        XCTAssertEqual(manager.shouldDetect(), false)
    }

    func testRemainingInitial() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        XCTAssertEqual(manager.getRemainingDetections(), ExposureDetectionTimingManager.maxDetections)
        XCTAssertEqual(manager.shouldDetect(), true)
    }

    func testRemainingAfterFirst() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        manager.addDetection()
        XCTAssertEqual(manager.getRemainingDetections(), ExposureDetectionTimingManager.maxDetections - 1)
        XCTAssertEqual(manager.shouldDetect(), false)
    }

    func testRemainginAfter1Day() {
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        for i in 0 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -.day - Double(20 - i) * .hour))
        }
        XCTAssertEqual(manager.getRemainingDetections(), ExposureDetectionTimingManager.maxDetections)
        XCTAssertEqual(manager.shouldDetect(), true)
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
        XCTAssertEqual(manager.shouldDetect(now: now), true)
    }

    func testTimeIntervalSinceLastDetectionNow(){
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        let last = Date()
        manager.addDetection(timestamp: last)
        for i in 1 ... 20 {
            manager.addDetection(timestamp: .init(timeIntervalSinceNow: -.day - Double(20 - i) * .hour))
        }
        XCTAssertEqual(manager.timeIntervalSinceLatestDetection(now: last), 0)
    }

    func testTimeIntervalSinceLastDetectionYesterday(){
        let defaults = MockDefaults()
        let manager = ExposureDetectionTimingManager(storage: defaults)
        let now = Date()
        let last = now.addingTimeInterval(-.day)
        manager.addDetection(timestamp: last)

        XCTAssertEqual(manager.timeIntervalSinceLatestDetection(now: now), TimeInterval.day)
    }
}
