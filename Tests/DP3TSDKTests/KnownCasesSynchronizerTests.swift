/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

@testable import DP3TSDK
import Foundation
import XCTest

fileprivate class MockMatcher: Matcher {
    var delegate: MatcherDelegate?

    func receivedNewKnownCaseData(_ data: Data, batchTimestamp: Date) throws {

    }

    func finalizeMatchingSession() throws {

    }
}

fileprivate class MockService: ExposeeServiceClientProtocol {
    var requests: [Date] = []
    func getExposeeSynchronously(batchTimestamp: Date) -> Result<Data?, DP3TNetworkingError> {
        requests.append(batchTimestamp)
        return .success("\(batchTimestamp.timeIntervalSince1970)".data(using: .utf8)!)
    }

    func addExposeeList(_ exposees: ExposeeListModel, authentication: ExposeeAuthMethod, completion: @escaping (Result<OutstandingPublish, DP3TNetworkingError>) -> Void) {

    }

    func addDelayedExposeeList(_ model: DelayedKeyModel, token: String?, completion: @escaping (Result<Void, DP3TNetworkingError>) -> Void) {

    }
}

final class KnownCasesSynchronizerTests: XCTestCase {
    func testInitialLastLoadedBatchValue(){
        let defaults = MockDefaults()
        defaults.parameters.networking.batchLength = .hour
        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        XCTAssertNotNil(defaults.lastLoadedBatchReleaseTime)
        XCTAssertLessThanOrEqual(defaults.lastLoadedBatchReleaseTime!, Date())
    }

    func testInitialNoBatch(){
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        defaults.parameters.networking.batchLength = .hour
        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults)
        let expecation = expectation(description: "syncExpectation")
        sync.sync { (result) in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests, [])

    }

    func testInitialLoadingFirstBatch(){
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        defaults.parameters.networking.batchLength = .hour
        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults)
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { (result) in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 1)
    }

    func testInitialLoadingManyBatches(){
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        defaults.parameters.networking.batchLength = .hour
        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults)
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour * 100)) { (result) in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 100)
    }
}

