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
    private var internalAttenutationDurations: [NSNumber] = [0,0,0]
}

fileprivate class MockManager: ENManager {

    var detectExposuresWasCalled = false

    var data: [Data] = []

    var summary = MockSummary()

    override func detectExposures(configuration: ENExposureConfiguration, diagnosisKeyURLs: [URL], completionHandler: @escaping ENDetectExposuresHandler) -> Progress {
        detectExposuresWasCalled = true
        completionHandler(summary,nil)
        diagnosisKeyURLs.forEach{
            let diagData = try! Data(contentsOf: $0)
            data.append(diagData)
        }
        return Progress()
    }

}

fileprivate class MockMatcherDelegate: MatcherDelegate {
    var matchedFound: Int = 0
    func didFindMatch() {
        matchedFound += 1
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

    func testCallingMatcherMultithreaded(){
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage)

        DispatchQueue.concurrentPerform(iterations: 50) { (_) in
            let data = "Some string!".data(using: .utf8)!
            guard let archive = Archive(accessMode: .create) else { return }
            try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
                return data.subdata(in: position..<position+size)
            })
            try! matcher.receivedNewKnownCaseData(archive.data!, keyDate: Date())
        }
        try! matcher.finalizeMatchingSession()
    }

    func testDetectingMatch(){
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let defaults = MockDefaults()
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage, defaults: defaults)
        let delegate = MockMatcherDelegate()
        matcher.delegate = delegate

        mockmanager.summary.attenuationDurations = [1800,1800,1800]

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            return data.subdata(in: position..<position+size)
        })
        try! matcher.receivedNewKnownCaseData(archive.data!, keyDate: Date())
        try! matcher.finalizeMatchingSession()
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
        XCTAssertEqual(delegate.matchedFound, 1)
    }

    func testDetectingMatchFirstBucketOnly(){
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let defaults = MockDefaults()
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage, defaults: defaults)
        let delegate = MockMatcherDelegate()
        matcher.delegate = delegate

        let firstBucket = Double(defaults.parameters.contactMatching.triggerThreshold * 60) / defaults.parameters.contactMatching.factorLow
        mockmanager.summary.attenuationDurations = [NSNumber(value: firstBucket) ,0,0]

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            return data.subdata(in: position..<position+size)
        })
        try! matcher.receivedNewKnownCaseData(archive.data!, keyDate: Date())
        try! matcher.finalizeMatchingSession()
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
        XCTAssertEqual(delegate.matchedFound, 1)
    }


    func testDetectingMatchSecondBucketOnly(){
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let defaults = MockDefaults()
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage, defaults: defaults)
        let delegate = MockMatcherDelegate()
        matcher.delegate = delegate

        let secondBucket = Double(defaults.parameters.contactMatching.triggerThreshold * 60) / defaults.parameters.contactMatching.factorHigh
        mockmanager.summary.attenuationDurations = [0,NSNumber(value: secondBucket),0]

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            return data.subdata(in: position..<position+size)
        })
        try! matcher.receivedNewKnownCaseData(archive.data!, keyDate: Date())
        try! matcher.finalizeMatchingSession()
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
        XCTAssertEqual(delegate.matchedFound, 1)
    }
}
