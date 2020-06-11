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

private extension CodableDiagnosisKey {
    static func mock(fake: Bool, rollingStartNumber: UInt32) -> CodableDiagnosisKey {
        CodableDiagnosisKey(keyData: "\(Int.random(in: 1000 ... 100_000))".data(using: .utf8)!, rollingPeriod: 144, rollingStartNumber: rollingStartNumber, transmissionRiskLevel: 1, fake: fake ? 1 : 0)
    }
}

private class MockManager: DiagnosisKeysProvider {
    var fakeAccessedCount: Int = 0
    var realAccessedCount: Int = 0

    var error: DP3TTracingError?
    var keys: [CodableDiagnosisKey] = []

    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        fakeAccessedCount += 1
        if let error = error {
            completionHandler(.failure(error))
        } else {
            completionHandler(.success(keys))
        }
    }

    func getDiagnosisKeys(onsetDate _: Date?, appDesc _: ApplicationDescriptor, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        realAccessedCount += 1
        if let error = error {
            completionHandler(.failure(error))
        } else {
            completionHandler(.success(keys))
        }
    }

    func getFakeKeys(count: Int, startingFrom: Date) -> [CodableDiagnosisKey] {
        return []
    }
}

private class ExposeeServiceClientMock: ExposeeServiceClient {
    var error: DP3TNetworkingError?
    var addedExposeeListCount: Int = 0

    init() {
        let descriptor = ApplicationDescriptor(appId: "XCD",
                                               bucketBaseUrl: URL(string: "https://ubique.ch")!,
                                               reportBaseUrl: URL(string: "https://ubique.ch")!,
                                               jwtPublicKey: nil,
                                               mode: .test)
        let session = MockSession(data: nil, urlResponse: nil, error: nil)
        super.init(descriptor: descriptor, urlSession: session, urlCache: .shared)
    }

    override func addDelayedExposeeList(_: DelayedKeyModel, token _: String?, completion: @escaping (Result<Void, DP3TNetworkingError>) -> Void) {
        addedExposeeListCount += 1
        if let error = error {
            completion(.failure(error))
        } else {
            completion(.success(()))
        }
    }
}

private class OutstandingPublishStorageMock: OutstandingPublishStorage {
    var removeCallCount: Int = 0

    override func remove(publish: OutstandingPublish) {
        removeCallCount += 1
        super.remove(publish: publish)
    }
}

final class OutstandingPublishOperationTests: XCTestCase {
    func testNoOperations() {
        let mockManager = MockManager()
        mockManager.keys = [.mock(fake: true, rollingStartNumber: 3)]

        let keychain = MockKeychain()
        let storage = OutstandingPublishStorageMock(keychain: keychain)

        let service = ExposeeServiceClientMock()

        let operationQueue = OperationQueue()
        let operationToTest = OutstandingPublishOperation(keyProvider: mockManager,
                                                          serviceClient: service,
                                                          storage: storage)

        operationQueue.addOperations([operationToTest], waitUntilFinished: true)

        XCTAssertEqual(storage.removeCallCount, 0)
        XCTAssertEqual(service.addedExposeeListCount, 0)
        XCTAssertEqual(mockManager.fakeAccessedCount, 0)
        XCTAssertEqual(mockManager.realAccessedCount, 0)
    }

    func testPublishingFake() {
        let mockManager = MockManager()
        mockManager.keys = [.mock(fake: true, rollingStartNumber: 3),
                            .mock(fake: true, rollingStartNumber: 3)]

        let keychain = MockKeychain()
        let storage = OutstandingPublishStorageMock(keychain: keychain)
        storage.add(OutstandingPublish(authorizationHeader: "ABCD", dayToPublish: Date(timeIntervalSinceNow: -86500), fake: true))

        let service = ExposeeServiceClientMock()

        let operationQueue = OperationQueue()
        let operationToTest = OutstandingPublishOperation(keyProvider: mockManager,
                                                          serviceClient: service,
                                                          storage: storage)

        operationQueue.addOperations([operationToTest], waitUntilFinished: true)

        XCTAssertEqual(storage.removeCallCount, 1)
        XCTAssertEqual(service.addedExposeeListCount, 1)
        XCTAssertEqual(mockManager.fakeAccessedCount, 1)
        XCTAssertEqual(mockManager.realAccessedCount, 0)
    }

    func testPublishingReal() {
        // Have 3 tasks to publish only 2 of them are in the past and valid.
        // Only one of these two have a valid key.
        let mockManager = MockManager()
        let firstDate = Date(timeIntervalSinceNow: -86500)
        let firstTimestamp = DayDate(date: firstDate).period
        mockManager.keys = [
            .mock(fake: false, rollingStartNumber: firstTimestamp),
            .mock(fake: false, rollingStartNumber: 34),
        ]

        let keychain = MockKeychain()
        let storage = OutstandingPublishStorageMock(keychain: keychain)

        storage.add(OutstandingPublish(authorizationHeader: "ABCD", dayToPublish: firstDate, fake: false))
        storage.add(OutstandingPublish(authorizationHeader: "ABCD", dayToPublish: Date(timeIntervalSinceNow: -88800), fake: false))
        storage.add(OutstandingPublish(authorizationHeader: "ABCD", dayToPublish: Date(timeIntervalSinceNow: 600), fake: false)) // In Future

        let service = ExposeeServiceClientMock()

        let operationQueue = OperationQueue()
        let operationToTest = OutstandingPublishOperation(keyProvider: mockManager,
                                                          serviceClient: service,
                                                          storage: storage)

        operationQueue.addOperations([operationToTest], waitUntilFinished: true)

        XCTAssertEqual(storage.removeCallCount, 2)
        XCTAssertEqual(service.addedExposeeListCount, 2)
        XCTAssertEqual(mockManager.fakeAccessedCount, 0)
        XCTAssertEqual(mockManager.realAccessedCount, 2)
    }

    func testPublishingDiagnosisKeyProviderError() {
        let mockManager = MockManager()
        mockManager.error = DP3TTracingError.permissonError

        let keychain = MockKeychain()
        let storage = OutstandingPublishStorageMock(keychain: keychain)
        storage.add(OutstandingPublish(authorizationHeader: "ABCD", dayToPublish: Date(timeIntervalSinceNow: -88800), fake: false))

        let service = ExposeeServiceClientMock()

        let operationQueue = OperationQueue()
        let operationToTest = OutstandingPublishOperation(keyProvider: mockManager,
                                                          serviceClient: service,
                                                          storage: storage)

        operationQueue.addOperations([operationToTest], waitUntilFinished: true)

        XCTAssertEqual(storage.removeCallCount, 0)
        XCTAssertEqual(service.addedExposeeListCount, 0)
        XCTAssertEqual(mockManager.fakeAccessedCount, 0)
        XCTAssertEqual(mockManager.realAccessedCount, 1)
    }

    func testPublishingExposeeServiceClientError() {
        let mockManager = MockManager()
        mockManager.keys = [
            .mock(fake: false, rollingStartNumber: 34),
        ]

        let keychain = MockKeychain()
        let storage = OutstandingPublishStorageMock(keychain: keychain)
        storage.add(OutstandingPublish(authorizationHeader: "ABCD", dayToPublish: Date(timeIntervalSinceNow: -88800), fake: true))

        let service = ExposeeServiceClientMock()
        service.error = DP3TNetworkingError.couldNotEncodeBody

        let operationQueue = OperationQueue()
        let operationToTest = OutstandingPublishOperation(keyProvider: mockManager,
                                                          serviceClient: service,
                                                          storage: storage)

        operationQueue.addOperations([operationToTest], waitUntilFinished: true)

        XCTAssertEqual(storage.removeCallCount, 0)
        XCTAssertEqual(service.addedExposeeListCount, 1)
        XCTAssertEqual(mockManager.fakeAccessedCount, 1)
        XCTAssertEqual(mockManager.realAccessedCount, 0)
    }
}
