/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

@testable import DP3TSDK
import Foundation
import XCTest
import ExposureNotification

/*
@available(iOS 13.5, *)
fileprivate class MockManager: ENManager {

    var detectExposuresWasCalled = false

    override func detectExposures(configuration: ENExposureConfiguration, diagnosisKeyURLs: [URL], completionHandler: @escaping ENDetectExposuresHandler) -> Progress {
        detectExposuresWasCalled = true
        let summary = ENExposureDetectionSummary()
        summary.attenuationDurations = [1800,1800]
        completionHandler(summary,nil)
        return Progress()
    }

}

@available(iOS 13.5, *)
final class ExposureNotificationMatcherTests: XCTestCase {
    var keychain = MockKeychain()

    override func tearDown() {
        keychain.reset()
    }
    
    func testCallingOfMatcher(){
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage)
        try! matcher.receivedNewKnownCaseData("data1".data(using: .utf8)!, batchTimestamp: Date())
        try! matcher.finalizeMatchingSession()
        XCTAssert(mockmanager.detectExposuresWasCalled)
    }
}
*/
