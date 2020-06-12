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

class InfectionStatusTests: XCTestCase {
    var keychain = MockKeychain()

    override func tearDown() {
        keychain.reset()
    }

    func testStorageSorting(){
        let storage = ExposureDayStorage(keychain: keychain)
        let day1 = Self.formatter.date(from: "19.01.2020 17:23")!
        let day2 = Self.formatter.date(from: "20.01.2020 17:23")!
        let day3 = Self.formatter.date(from: "21.01.2020 17:23")!
        storage.add(.init(identifier: UUID(), exposedDate: day1, reportDate: .init(), isDeleted: false))
        storage.add(.init(identifier: UUID(), exposedDate: day2, reportDate: .init(), isDeleted: false))
        storage.add(.init(identifier: UUID(), exposedDate: day3, reportDate: .init(), isDeleted: false))
        let days = storage.getDays()
        XCTAssertEqual(DayDate(date: days[0].exposedDate), DayDate(date: day3))
        XCTAssertEqual(DayDate(date: days[1].exposedDate), DayDate(date: day2))
        XCTAssertEqual(DayDate(date: days[2].exposedDate), DayDate(date: day1))
    }

    func testHealthy() {
        let storage = ExposureDayStorage(keychain: keychain)
        let mockDefaults = MockDefaults()
        mockDefaults.didMarkAsInfected = false
        let state = InfectionStatus.getInfectionState(from: storage, defaults: mockDefaults)
        switch state {
        case .healthy:
            break
        default:
            XCTFail()
        }
    }

    func testInfected() {
        let storage = ExposureDayStorage(keychain: keychain)
        let mockDefaults = MockDefaults()
        mockDefaults.didMarkAsInfected = true
        let state = InfectionStatus.getInfectionState(from: storage, defaults: mockDefaults)
        switch state {
        case .infected:
            break
        default:
            XCTFail()
        }
    }

    func testExposed() {
        let storage = ExposureDayStorage(keychain: keychain)
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(), isDeleted: false))
        let mockDefaults = MockDefaults()
        mockDefaults.didMarkAsInfected = false
        let state = InfectionStatus.getInfectionState(from: storage, defaults: mockDefaults)
        switch state {
        case .exposed:
            break
        default:
            XCTFail()
        }
    }

    func testExposedReturnNewestDay() {
        let storage = ExposureDayStorage(keychain: keychain)
        let day1 = Self.formatter.date(from: "19.01.2020 17:23")!
        let day2 = Self.formatter.date(from: "20.01.2020 17:23")!
        let day3 = Self.formatter.date(from: "21.01.2020 17:23")!
        storage.add(.init(identifier: UUID(), exposedDate: day1, reportDate: .init(), isDeleted: false))
        storage.add(.init(identifier: UUID(), exposedDate: day2, reportDate: .init(), isDeleted: false))
        storage.add(.init(identifier: UUID(), exposedDate: day3, reportDate: .init(), isDeleted: false))
        let mockDefaults = MockDefaults()
        mockDefaults.didMarkAsInfected = false
        let state = InfectionStatus.getInfectionState(from: storage, defaults: mockDefaults)
        switch state {
        case let .exposed(days):
            XCTAssertEqual(days.count, 1)
            XCTAssertEqual(DayDate(date: days.first!.exposedDate), DayDate(date: day3))
        default:
            XCTFail()
        }
    }

    func testHelthyDeletedExposed() {
        let storage = ExposureDayStorage(keychain: keychain)
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(), isDeleted: true))
        let mockDefaults = MockDefaults()
        mockDefaults.didMarkAsInfected = false
        let state = InfectionStatus.getInfectionState(from: storage, defaults: mockDefaults)
        switch state {
        case .healthy:
            break
        default:
            XCTFail()
        }
    }

    static var formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy HH:mm"
        return df
    }()
}
