/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import SQLite
import XCTest

final class DatabaseTests: XCTestCase {
    let connection = try! Connection(.inMemory, readonly: false)

    lazy var database: DP3TDatabase! = try! DP3TDatabase(connection_: connection)

    override func tearDown() {
        try! database.emptyStorage()
    }

    func testMarkingExposuresAsDeleted(){
        try! database.exposureDaysStorage.add(.init(identifier: 0, exposedDate: .init(), reportDate: .init(), isDeleted: false))
        let days = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(days.count, 1)
        try! database.exposureDaysStorage.markExposuresAsDeleted()
        let deletedDays = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(deletedDays.count, 0)
    }
}
