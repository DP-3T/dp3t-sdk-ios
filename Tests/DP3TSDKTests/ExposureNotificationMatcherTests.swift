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
import Foundation
import XCTest
import ZIPFoundation

final class ExposureNotificationMatcherTests: XCTestCase {
    var keychain = MockKeychain()

    override func tearDown() {
        keychain.reset()
    }

    func testCallingOfMatcher() {
        let mockmanager = MockENManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage)

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            data.subdata(in: position ..< position + size)
        })
        _ = try! matcher.receivedNewData(archive.data!)
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
    }

    func testCallingMatcherMultithreaded() {
        let mockmanager = MockENManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage)

        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            let data = "Some string!".data(using: .utf8)!
            guard let archive = Archive(accessMode: .create) else { return }
            try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
                data.subdata(in: position ..< position + size)
            })
            _ = try! matcher.receivedNewData(archive.data!)
        }
    }

    func testDetectingMatch() {
        let mockmanager = MockENManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let defaults = MockDefaults()
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage, defaults: defaults)

        let window = MockWindow(date: .init(), scanInstances: [])
        for _ in 0...5 {
            window.scanInstances.append(MockScanInstance(typicalAttenuation: UInt8(defaults.parameters.contactMatching.lowerThreshold - 1), secondsSinceLastScan: 180))
            window.scanInstances.append(MockScanInstance(typicalAttenuation: UInt8(defaults.parameters.contactMatching.higherThreshold - 1), secondsSinceLastScan: 180))
        }
        mockmanager.windows.append(window)

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            data.subdata(in: position ..< position + size)
        })
        let foundMatch = try! matcher.receivedNewData(archive.data!)
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
        XCTAssertEqual(foundMatch, true)
    }

    func testDetectingMatchFirstBucketOnly() {
        let mockmanager = MockENManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let defaults = MockDefaults()
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage, defaults: defaults)

        let secondsFirstBucket = Double(defaults.parameters.contactMatching.triggerThreshold * 60) / defaults.parameters.contactMatching.factorLow
        let window = MockWindow(date: .init(), scanInstances: [])
        for _ in 0...Int(ceil(secondsFirstBucket / 180)) {
            window.scanInstances.append(MockScanInstance(typicalAttenuation: UInt8(defaults.parameters.contactMatching.lowerThreshold - 1), secondsSinceLastScan: 180))
        }
        mockmanager.windows.append(window)

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            data.subdata(in: position ..< position + size)
        })
        let foundMatch = try! matcher.receivedNewData(archive.data!)
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
        XCTAssertEqual(foundMatch, true)
    }

    func testDetectingMatchSecondBucketOnly() {
        let mockmanager = MockENManager()
        let storage = ExposureDayStorage(keychain: keychain)
        let defaults = MockDefaults()
        let matcher = ExposureNotificationMatcher(manager: mockmanager, exposureDayStorage: storage, defaults: defaults)

        let secondsSecondBucket = Double(defaults.parameters.contactMatching.triggerThreshold * 60) / defaults.parameters.contactMatching.factorHigh
        let window = MockWindow(date: .init(), scanInstances: [])
        for _ in 0...Int(ceil(secondsSecondBucket / 180)) {
            window.scanInstances.append(MockScanInstance(typicalAttenuation: UInt8(defaults.parameters.contactMatching.higherThreshold - 1), secondsSinceLastScan: 180))
        }
        mockmanager.windows.append(window)

        let data = "Some string!".data(using: .utf8)!
        guard let archive = Archive(accessMode: .create) else { return }
        try! archive.addEntry(with: "inMemory.bin", type: .file, uncompressedSize: 12, bufferSize: 4, provider: { (position, size) -> Data in
            data.subdata(in: position ..< position + size)
        })
        let foundMatch = try! matcher.receivedNewData(archive.data!)
        XCTAssert(mockmanager.detectExposuresWasCalled)
        XCTAssert(mockmanager.data.contains(data))
        XCTAssertEqual(foundMatch, true)
    }
}
