/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import SQLite
import XCTest

final class ExposureDayTests: DatabaseTestBase {
    func testMarkingExposuresAsDeleted(){
        try! database.exposureDaysStorage.add(.init(identifier: 0, exposedDate: .init(), reportDate: .init(), isDeleted: false))
        let days = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(days.count, 1)
        try! database.exposureDaysStorage.markExposuresAsDeleted()
        let deletedDays = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(deletedDays.count, 0)

        let count = try! database.exposureDaysStorage.count()
        XCTAssertEqual(count, 0)
    }

    func testOneExposureDayPerDay(){
        let dayMin = DayDate().dayMin
        try! database.exposureDaysStorage.add(.init(identifier: 0, exposedDate: dayMin, reportDate: .init(), isDeleted: false))
        var days = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(days.count, 1)
        try! database.exposureDaysStorage.add(.init(identifier: 0, exposedDate: dayMin.addingTimeInterval(.hour), reportDate: .init(), isDeleted: false))
        days = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(days.count, 1)
        let count = try! database.exposureDaysStorage.count()
        XCTAssertEqual(count, 1)
    }
}
