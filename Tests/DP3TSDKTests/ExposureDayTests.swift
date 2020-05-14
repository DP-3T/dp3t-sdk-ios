/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
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
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(timeIntervalSinceNow: .day * Double(parameters.crypto.numberOfDaysToKeepData) * (-1)), isDeleted: false))
        XCTAssertEqual(storage.count, 1)
        storage.deleteExpiredExpsureDays()
        XCTAssertEqual(storage.count, 0)
    }

    func testNotDeletionExpiredDays() {
        let parameters = DP3TParameters()
        let storage = ExposureDayStorage(keychain: keychain, parameters: parameters)
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(timeIntervalSinceNow: .day * Double(parameters.crypto.numberOfDaysToKeepData - 1) * (-1)), isDeleted: false))
        XCTAssertEqual(storage.count, 1)
        storage.deleteExpiredExpsureDays()
        XCTAssertEqual(storage.count, 0)
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
