/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import Foundation
import SQLite
import XCTest

private class MockMatcher: Matcher {
    func receivedNewKnownCaseData(_ data: Data, batchTimestamp _: Date) throws {
        let models = try! JSONDecoder().decode([KnownCaseModel].self, from: data)
        knownCaseKeys.append(contentsOf: models.map(\.key))
    }

    func finalizeMatchingSession() throws {}

    var delegate: MatcherDelegate?

    var knownCaseKeys: [Data] = []
}

private class MockService: ExposeeServiceClientProtocol {
    var models: [KnownCaseModel] = []
    var requests: Int = 0

    func getExposeeSynchronously(batchTimestamp _: Date) -> ExposeeResult {
        requests += 1
        let data = try! JSONEncoder().encode(models)
        return .success(data)
    }

    func addExposee(_: ExposeeModel, authentication _: ExposeeAuthMethod, completion _: @escaping (ExposeeCompletion) -> Void) {}
}

final class KnownCasesSynchronizerTests: XCTestCase {
    let connection = try! Connection(.inMemory, readonly: false)

    lazy var database: DP3TDatabase! = try! DP3TDatabase(connection_: connection)

    override func tearDown() {
        try! database.emptyStorage()
    }

    fileprivate func getMockService(array: [KnownCaseModel] = []) -> MockService {
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
        synchronizer.sync(service: service) { result in
            if case .success = result {
                XCTAssertEqual(service.requests, 0)
                let nowTs = Date().timeIntervalSince1970
                let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength)
                XCTAssertEqual(defaults.lastLoadedBatchReleaseTime!.timeIntervalSince1970, lastBatchTs, accuracy: 1.0)
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { _ in
            XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testNotFirstLaunch() {
        let defaults = MockDefaults()
        do {
            let nowTs = Date().addingTimeInterval(Default.shared.parameters.networking.batchLength * 100 * (-1)).timeIntervalSince1970
            let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength)
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
        synchronizer.sync(service: service) { result in
            if case .success = result {
                XCTAssertEqual(service.requests, 100)
                let nowTs = Date().timeIntervalSince1970
                let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength)
                XCTAssertEqual(defaults.lastLoadedBatchReleaseTime!.timeIntervalSince1970, lastBatchTs, accuracy: 1.0)
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { _ in
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
        synchronizer.sync(service: service) { result in
            if case .success = result {
                XCTAssertEqual(service.requests, 0)
                let nowTs = Date().timeIntervalSince1970
                let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength)
                XCTAssertEqual(defaults.lastLoadedBatchReleaseTime!.timeIntervalSince1970, lastBatchTs, accuracy: 1.0)
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { _ in
            XCTAssertNotNil(exposeeExpectation)
        }

        exposeeExpectation = expectation(description: "exposee")

        let nextSync = Date().addingTimeInterval(Default.shared.parameters.networking.batchLength * 24)
        synchronizer.sync(service: service, now: nextSync) { result in
            if case .success = result {
                XCTAssertEqual(service.requests, 24)
                let nowTs = nextSync.timeIntervalSince1970
                let lastBatchTs = nowTs - nowTs.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength)
                XCTAssertEqual(defaults.lastLoadedBatchReleaseTime!.timeIntervalSince1970, lastBatchTs, accuracy: 1.0)
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { _ in
            XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testCallingOfMatcher() {
        let b64Key = "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI="
        let key = Data(base64Encoded: b64Key)!
        let defaults = MockDefaults()
        let now = Date().timeIntervalSince1970
        let ts = now - now.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength)
        defaults.lastLoadedBatchReleaseTime = Date(timeIntervalSince1970: ts - Default.shared.parameters.networking.batchLength)
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
        synchronizer.sync(service: service) { result in

            if case .success = result {
                XCTAssertEqual(matcher.knownCaseKeys.count, 1)
                XCTAssert(matcher.knownCaseKeys.contains(key))
            } else {
                XCTFail()
            }

            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { _ in
            XCTAssertNotNil(exposeeExpectation)
        }
    }

    static var allTests = [
        ("testFirstLaunchNoRequests", testFirstLaunchNoRequests),
        ("testNotFirstLaunch", testNotFirstLaunch),
        ("testCallingOfMatcher", testCallingOfMatcher),
        ("testFirstAndSecondLaunch", testFirstAndSecondLaunch),
    ]
}
