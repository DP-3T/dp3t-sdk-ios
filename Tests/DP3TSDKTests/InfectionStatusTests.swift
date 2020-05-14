/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest

class InfectionStatusTests: XCTestCase {
    var keychain = MockKeychain()

    override func tearDown() {
        keychain.reset()
    }

    func testHealthy() {
        let storage = ExposureDayStorage(keychain: keychain)
        let mockDefaults = MockDefaults()
        mockDefaults.didMarkAsInfected = false
        let state = InfectionStatus.getInfectionState(from: storage, defaults: mockDefaults)
        switch state {
        case .healthy:
            break
        default:
            XCTFail()
        }
    }

    func testInfected() {
        let storage = ExposureDayStorage(keychain: keychain)
        let mockDefaults = MockDefaults()
        mockDefaults.didMarkAsInfected = true
        let state = InfectionStatus.getInfectionState(from: storage, defaults: mockDefaults)
        switch state {
        case .infected:
            break
        default:
            XCTFail()
        }
    }

    func testExposed() {
        let storage = ExposureDayStorage(keychain: keychain)
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(), isDeleted: false))
        let mockDefaults = MockDefaults()
        mockDefaults.didMarkAsInfected = false
        let state = InfectionStatus.getInfectionState(from: storage, defaults: mockDefaults)
        switch state {
        case .exposed:
            break
        default:
            XCTFail()
        }
    }

    func testHelthyDeletedExposed() {
        let storage = ExposureDayStorage(keychain: keychain)
        storage.add(.init(identifier: UUID(), exposedDate: .init(), reportDate: .init(), isDeleted: true))
        let mockDefaults = MockDefaults()
        mockDefaults.didMarkAsInfected = false
        let state = InfectionStatus.getInfectionState(from: storage, defaults: mockDefaults)
        switch state {
        case .healthy:
            break
        default:
            XCTFail()
        }
    }
}
