/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

@testable import DP3TSDK
import ExposureNotification
import Foundation
import XCTest
import ZIPFoundation

fileprivate class MockSummary: ENExposureDetectionSummary {
    override var attenuationDurations: [NSNumber] {
        get {
            internalAttenutationDurations
        }
        set {
            internalAttenutationDurations = newValue
        }
    }
    private var internalAttenutationDurations: [NSNumber] = []
}

fileprivate class MockManager: ENManager {

    var detectExposuresWasCalled = false

    var data: [Data] = []

    override func detectExposures(configuration: ENExposureConfiguration, diagnosisKeyURLs: [URL], completionHandler: @escaping ENDetectExposuresHandler) -> Progress {
        detectExposuresWasCalled = true
        let summary = MockSummary()
        summary.attenuationDurations = [0,0,0]
        completionHandler(summary,nil)
        diagnosisKeyURLs.forEach{
            let diagData = try! Data(contentsOf: $0)
            data.append(diagData)
        }
        return Progress()
    }

}

final class ExposureNotificationMatcherTests: XCTestCase {
    var keychain = MockKeychain()

    override func tearDown() {
        keychain.reset()
    }

    func testCallingOfMatcher(){
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage)

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            return data.subdata(in: position..<position+size)
        })
        try! matcher.receivedNewKnownCaseData(archive.data!, keyDate: Date())
        try! matcher.finalizeMatchingSession()
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
    }
}
