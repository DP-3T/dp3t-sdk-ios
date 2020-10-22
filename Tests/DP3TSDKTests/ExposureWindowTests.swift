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
import XCTest
import ExposureNotification


class ExposureWindowTests: XCTestCase {
    func testDayGroupingSingle(){
        var windows: [MockWindow] = []
        windows.append(.init(date: date("01.08.2020"), scanInstances: [MockScanInstance(typicalAttenuation: 50, secondsSinceLastScan: 10)]))
        windows.append(.init(date: date("01.08.2020"), scanInstances: [MockScanInstance(typicalAttenuation: 50, secondsSinceLastScan: 20)]))
        windows.append(.init(date: date("01.08.2020"), scanInstances: [MockScanInstance(typicalAttenuation: 50, secondsSinceLastScan: 30)]))
        windows.append(.init(date: date("01.08.2020"), scanInstances: [MockScanInstance(typicalAttenuation: 50, secondsSinceLastScan: 40)]))
        let groupes = windows.groupByDay
        XCTAssertEqual(groupes.count, 1)
        XCTAssertEqual(groupes.keys.first!, date("01.08.2020"))
        XCTAssertEqual(groupes.first?.value.count, 4)
        XCTAssertEqual(groupes.first?.value
            .compactMap { $0.scanInstances }
            .joined()
            .map(\.secondsSinceLastScan)
            .reduce(0, +), 100)
    }

    func testGroupingMultipleDays(){
        let startingDay = date("01.08.2020")
        var windows: [MockWindow] = []
        for i in 0..<50 {
            windows.append(.init(date: startingDay.addingTimeInterval(.day * Double(i)),
                                 scanInstances: [MockScanInstance(typicalAttenuation: 50, secondsSinceLastScan: 180)]))
        }
        let groups = windows.groupByDay
        XCTAssertEqual(groups.count, 50)
        for i in 0..<50 {
            XCTAssert(groups.keys.contains(startingDay.addingTimeInterval(.day * Double(i))))
        }
        groups.values.forEach { (window) in
            XCTAssertEqual(window.count, 1)
        }
    }

    func testComputingSeconds() {
        let windows: [ENExposureWindow] = [MockWindow(date: Date(), scanInstances: [
            MockScanInstance(typicalAttenuation: 20, secondsSinceLastScan: 22),
            MockScanInstance(typicalAttenuation: 30, secondsSinceLastScan: 55),
            MockScanInstance(typicalAttenuation: 40, secondsSinceLastScan: 77)
        ])]

        let values = windows.attenuationValues(lowerThreshold: 25, higherThreshold: 45)

        XCTAssertEqual(values.lowerBucket, 22)
        XCTAssertEqual(values.higherBucket, 55 + 77)
    }


    func date(_ string: String) -> Date {
        return Self.formatter.date(from: string)!
    }

    static var formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        return df
    }()
}
