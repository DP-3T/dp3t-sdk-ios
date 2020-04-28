/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
@testable import DP3TSDK
import XCTest
import SQLite

fileprivate class MockMatcher: DP3TMatcherProtocol {
    var knownCaseKeys: [Data] = []
    func checkNewKnownCase(_ knownCase: KnownCaseModel) throws {
        knownCaseKeys.append(knownCase.key)
    }
}

fileprivate class MockService: ExposeeServiceClientProtocol {
    var models: [KnownCaseModel] = []
    var requests: Int = 0

    func getExposeeSynchronously(batchTimestamp: Date) -> ExposeeResult {
        requests += 1
        return .success(models)
    }

    func addExposee(_ exposee: ExposeeModel, authentication: ExposeeAuthMethod, completion: @escaping (ExposeeCompletion) -> Void) {}
}

final class KnownCasesSynchronizerTests: XCTestCase {

    let connection = try! Connection(.inMemory, readonly: false)

    lazy var database: DP3TDatabase! = try! DP3TDatabase(connection_: connection)

    override func tearDown() {
        try! database.emptyStorage()
    }

    fileprivate func getMockService(array: [KnownCaseModel] = []) -> MockService{
        let service = MockService()
        service.models = array
        return service
    }

    func testFirstLaunchNoRequests() {

        let defaults = MockDefaults()
        let matcher = MockMatcher()
        let service = getMockService()
        let appInfo = DP3TApplicationInfo.discovery("ch.xy", enviroment: .dev)
        let synchronizer = KnownCasesSynchronizer(appInfo: appInfo,
                                                  database: database,
                                                  matcher: matcher,
                                                  defaults: defaults)
        let exposeeExpectation = expectation(description: "exposee")

        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        synchronizer.sync(service: service) { (result) in
            if case .success = result {
                XCTAssertEqual(service.requests, 0)
                let nowTs = Date().timeIntervalSince1970
                let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)
                XCTAssertEqual(defaults.lastLoadedBatchReleaseTime!.timeIntervalSince1970, lastBatchTs, accuracy: 1.0)
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }

    }

    func testNotFirstLaunch() {
        let defaults = MockDefaults()
        do {
            let nowTs = Date().addingTimeInterval(NetworkingConstants.batchLength * 100 * (-1)).timeIntervalSince1970
            let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)
            defaults.lastLoadedBatchReleaseTime = Date(timeIntervalSince1970: lastBatchTs)
        }
        let matcher = MockMatcher()
        let service = getMockService()
        let appInfo = DP3TApplicationInfo.discovery("ch.xy", enviroment: .dev)
        let synchronizer = KnownCasesSynchronizer(appInfo: appInfo,
                                                  database: database,
                                                  matcher: matcher,
                                                  defaults: defaults)
        let exposeeExpectation = expectation(description: "exposee")

        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        synchronizer.sync(service: service) { (result) in
            if case .success = result {
                XCTAssertEqual(service.requests, 100)
                let nowTs = Date().timeIntervalSince1970
                let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)
                XCTAssertEqual(defaults.lastLoadedBatchReleaseTime!.timeIntervalSince1970, lastBatchTs, accuracy: 1.0)
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }

    }

    func testFirstAndSecondLaunch() {
        let defaults = MockDefaults()
        let matcher = MockMatcher()
        let service = getMockService()
        let appInfo = DP3TApplicationInfo.discovery("ch.xy", enviroment: .dev)
        let synchronizer = KnownCasesSynchronizer(appInfo: appInfo,
                                                  database: database,
                                                  matcher: matcher,
                                                  defaults: defaults)
        var exposeeExpectation = expectation(description: "exposee")

        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        synchronizer.sync(service: service) { (result) in
            if case .success = result {
                XCTAssertEqual(service.requests, 0)
                let nowTs = Date().timeIntervalSince1970
                let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)
                XCTAssertEqual(defaults.lastLoadedBatchReleaseTime!.timeIntervalSince1970, lastBatchTs, accuracy: 1.0)
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }

        exposeeExpectation = expectation(description: "exposee")

        let nextSync = Date().addingTimeInterval(NetworkingConstants.batchLength * 24)
        synchronizer.sync(service: service, now: nextSync) { (result) in
            if case .success = result {
                XCTAssertEqual(service.requests, 24)
                let nowTs = nextSync.timeIntervalSince1970
                let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)
                XCTAssertEqual(defaults.lastLoadedBatchReleaseTime!.timeIntervalSince1970, lastBatchTs, accuracy: 1.0)
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testCallingOfMatcher(){
        let b64Key = "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI="
        let key = Data(base64Encoded: b64Key)!
        let defaults = MockDefaults()
        let now = Date().timeIntervalSince1970
        let ts = now - now.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)
        defaults.lastLoadedBatchReleaseTime = Date(timeIntervalSince1970: ts - NetworkingConstants.batchLength)
        let matcher = MockMatcher()
        let knownCase = KnownCaseModel(id: nil, key: key, onset: Date(), batchTimestamp: Date())
        let service = getMockService(array: [knownCase])
        let appInfo = DP3TApplicationInfo.discovery("ch.xy", enviroment: .dev)
        let synchronizer = KnownCasesSynchronizer(appInfo: appInfo,
                                                  database: database,
                                                  matcher: matcher,
                                                  defaults: defaults)
        let exposeeExpectation = expectation(description: "exposee")
        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        synchronizer.sync(service: service) { (result) in

            if case .success = result {
                XCTAssertEqual(matcher.knownCaseKeys.count, 1)
                XCTAssert(matcher.knownCaseKeys.contains(key))
                XCTAssertEqual(try! self.database.knownCasesStorage.getId(for: key), 1)
            } else {
                XCTFail()
            }

            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }
    }

    static var allTests = [
        ("testFirstLaunchNoRequests", testFirstLaunchNoRequests),
        ("testNotFirstLaunch", testNotFirstLaunch),
        ("testCallingOfMatcher", testCallingOfMatcher),
        ("testFirstAndSecondLaunch", testFirstAndSecondLaunch)
    ]
}
