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
import ExposureNotification

class DiagnosisKeysProviderTests: XCTestCase {

    var manager: MockENManager!
    var descriptor: ApplicationDescriptor!

    override func setUp() {
        manager = MockENManager()
        descriptor = ApplicationDescriptor(appId: "org.dpppt", bucketBaseUrl: URL(string: "http://google.com")!, reportBaseUrl: URL(string: "http://google.com")!)
    }

    func testFilteringOfOldTests(){
        let onset = Date().addingTimeInterval(.day * -100)
        let day = DayDate(date: Date().addingTimeInterval(.day * (-15)))
        manager.keys = [.initialize(rollingStartNumber: day.period)]

        let exp = expectation(description: "getDiagnosisKeys")
        manager.getDiagnosisKeys(onsetDate: onset, appDesc: descriptor) { (result) in
            switch result {
            case .failure(_):
                XCTFail()
            case let .success(keys):
                XCTAssert(keys.isEmpty)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 0.1)
    }

    func testNotFilteringNewTests(){
        let onset = Date().addingTimeInterval(.day * -14)
        let day = DayDate(date: Date().addingTimeInterval(.day * (-13)))
        manager.keys = [.initialize(rollingStartNumber: day.period)]

        let exp = expectation(description: "getDiagnosisKeys")
        manager.getDiagnosisKeys(onsetDate: onset, appDesc: descriptor) { (result) in
            switch result {
            case .failure(_):
                XCTFail()
            case let .success(keys):
                XCTAssert(!keys.isEmpty)
                XCTAssertEqual(keys.count, 1)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 0.1)
    }

    func testFilteringOnsetDate(){
        let onset = Date().addingTimeInterval(.day * -13)
        let day = DayDate(date: Date().addingTimeInterval(.day * (-14)))
        manager.keys = [.initialize(rollingStartNumber: day.period)]

        let exp = expectation(description: "getDiagnosisKeys")
        manager.getDiagnosisKeys(onsetDate: onset, appDesc: descriptor) { (result) in
            switch result {
            case .failure(_):
                XCTFail()
            case let .success(keys):
                XCTAssert(keys.isEmpty)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 0.1)
    }
    
}

extension ENTemporaryExposureKey {
    static func initialize(data: Data = Data(capacity: 16),
                           rollingPeriod: ENIntervalNumber = UInt32(TimeInterval.day / (.minute * 10)),
                           rollingStartNumber: ENIntervalNumber,
                           transmissionRiskLevel: ENRiskLevel = 0 ) -> ENTemporaryExposureKey {
        let key = ENTemporaryExposureKey()
        key.keyData = data
        key.rollingPeriod = rollingPeriod
        key.rollingStartNumber = rollingStartNumber
        key.transmissionRiskLevel = transmissionRiskLevel
        return key
    }
}
