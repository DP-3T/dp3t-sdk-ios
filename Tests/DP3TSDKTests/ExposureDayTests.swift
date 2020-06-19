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

final class ExposureDayTests: XCTestCase {
    var keychain = MockKeychain()

    override func tearDown() {
        keychain.reset()
    }

    func testDeletionExpiredDays() {
        let parameters = DP3TParameters()
        let storage = ExposureDayStorage(keychain: keychain, parameters: parameters)
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(timeIntervalSinceNow: .day * Double(parameters.crypto.numberOfDaysToKeepMatchedContacts + 1) * (-1)), isDeleted: false))
        XCTAssertEqual(storage.count, 1)
        storage.deleteExpiredExposureDays()
        XCTAssertEqual(storage.count, 0)
    }

    func testNotDeletionExpiredDays() {
        let parameters = DP3TParameters()
        let storage = ExposureDayStorage(keychain: keychain, parameters: parameters)
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(timeIntervalSinceNow: .day * Double(parameters.crypto.numberOfDaysToKeepMatchedContacts - 1) * (-1)), isDeleted: false))
        XCTAssertEqual(storage.count, 1)
        storage.deleteExpiredExposureDays()
        XCTAssertEqual(storage.count, 1)
    }

    func testMarkingExposuresAsDeleted() {
        let storage = ExposureDayStorage(keychain: keychain)
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(), isDeleted: false))
        XCTAssertEqual(storage.count, 1)
        let days = storage.getDays()
        XCTAssertEqual(days.count, 1)
        storage.markExposuresAsDeleted()
        let deletedDays = storage.getDays()
        XCTAssertEqual(deletedDays.count, 0)
        XCTAssertEqual(storage.count, 0)
        let notFiltered = storage.getDays(filtered: false)
        XCTAssertEqual(notFiltered.count, 1)
        XCTAssertEqual(notFiltered.first!.isDeleted, true)
    }

    func testOneExposureDayPerDay() {
        let storage = ExposureDayStorage(keychain: keychain)
        let dayMin = DayDate().dayMin
        storage.add(.init(identifier: UUID(), exposedDate: dayMin, reportDate: .init(), isDeleted: false))
        XCTAssertEqual(storage.count, 1)
        var days = storage.getDays()
        XCTAssertEqual(days.count, 1)
        storage.add(.init(identifier: UUID(), exposedDate: dayMin.addingTimeInterval(.hour), reportDate: .init(), isDeleted: false))
        XCTAssertEqual(storage.count, 1)
        days = storage.getDays()
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(storage.count, 1)
    }

    func testReset() {
        let storage = ExposureDayStorage(keychain: keychain)
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(), isDeleted: false))
        XCTAssertEqual(storage.count, 1)
        storage.reset()
        XCTAssertEqual(storage.count, 0)
    }
}
