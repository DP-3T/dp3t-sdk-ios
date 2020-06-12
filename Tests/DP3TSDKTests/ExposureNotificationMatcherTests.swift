/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation

@testable import DP3TSDK
import ExposureNotification
import Foundation
import XCTest
import ZIPFoundation

private class MockSummary: ENExposureDetectionSummary {
    override var attenuationDurations: [NSNumber] {
        get {
            internalAttenutationDurations
        }
        set {
            internalAttenutationDurations = newValue
        }
    }

    private var internalAttenutationDurations: [NSNumber] = [0, 0, 0]
}

private class MockManager: ENManager {
    var detectExposuresWasCalled = false

    var data: [Data] = []

    var summary = MockSummary()

    override func detectExposures(configuration _: ENExposureConfiguration, diagnosisKeyURLs: [URL], completionHandler: @escaping ENDetectExposuresHandler) -> Progress {
        detectExposuresWasCalled = true
        completionHandler(summary, nil)
        diagnosisKeyURLs.forEach {
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

    func testCallingOfMatcher() {
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage)

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            data.subdata(in: position ..< position + size)
        })
        _ = try! matcher.receivedNewData(archive.data!, keyDate: Date())
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
    }

    func testCallingMatcherMultithreaded() {
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage)

        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            let data = "Some string!".data(using: .utf8)!
            guard let archive = Archive(accessMode: .create) else { return }
            try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
                data.subdata(in: position ..< position + size)
            })
            _ = try! matcher.receivedNewData(archive.data!, keyDate: Date())
        }
    }

    func testDetectingMatch() {
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let defaults = MockDefaults()
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage, defaults: defaults)

        mockmanager.summary.attenuationDurations = [1800, 1800, 1800]

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            data.subdata(in: position ..< position + size)
        })
        let foundMatch = try! matcher.receivedNewData(archive.data!, keyDate: Date())
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
        XCTAssertEqual(foundMatch, true)
    }

    func testDetectingMatchFirstBucketOnly() {
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let defaults = MockDefaults()
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage, defaults: defaults)

        let firstBucket = Double(defaults.parameters.contactMatching.triggerThreshold * 60) / defaults.parameters.contactMatching.factorLow
        mockmanager.summary.attenuationDurations = [NSNumber(value: firstBucket), 0, 0]

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            data.subdata(in: position ..< position + size)
        })
        let foundMatch = try! matcher.receivedNewData(archive.data!, keyDate: Date())
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
        XCTAssertEqual(foundMatch, true)
    }

    func testDetectingMatchSecondBucketOnly() {
        let mockmanager = MockManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let defaults = MockDefaults()
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage, defaults: defaults)

        let secondBucket = Double(defaults.parameters.contactMatching.triggerThreshold * 60) / defaults.parameters.contactMatching.factorHigh
        mockmanager.summary.attenuationDurations = [0, NSNumber(value: secondBucket), 0]

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            data.subdata(in: position ..< position + size)
        })
        let foundMatch = try! matcher.receivedNewData(archive.data!, keyDate: Date())
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
        XCTAssertEqual(foundMatch, true)
    }
}
