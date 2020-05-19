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

    func receivedNewKnownCaseData(_ data: Data, keyDate batchTimestamp: Date) throws {

    }

    func finalizeMatchingSession() throws {

    }
}

fileprivate class MockService: ExposeeServiceClientProtocol {
    var requests: [Date] = []
    func getExposeeSynchronously(batchTimestamp: Date, publishedAfter: Date?) -> Result<ExposeeSuccess?, DP3TNetworkingError> {
        requests.append(batchTimestamp)
        return .success(.init(data: "\(batchTimestamp.timeIntervalSince1970)".data(using: .utf8)!, publishedUntil: batchTimestamp))
    }

    func addExposeeList(_ exposees: ExposeeListModel, authentication: ExposeeAuthMethod, completion: @escaping (Result<OutstandingPublish, DP3TNetworkingError>) -> Void) {

    }

    func addDelayedExposeeList(_ model: DelayedKeyModel, token: String?, completion: @escaping (Result<Void, DP3TNetworkingError>) -> Void) {

    }
}

@available(iOS 13.5, *)
final class KnownCasesSynchronizerTests: XCTestCase {
    func testInitialLastLoadedBatchValue(){
        let defaults = MockDefaults()
        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        XCTAssertNotNil(defaults.installationDate)
        XCTAssertLessThanOrEqual(defaults.installationDate!, Date())
    }

    func testInitialToday(){
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults)
        let expecation = expectation(description: "syncExpectation")
        sync.sync { (result) in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 1)
        XCTAssertEqual(service.requests.first!, DayDate().dayMin)

    }

    func testInitialLoadingFirstBatch(){
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
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
        KnownCasesSynchronizer.initializeSynchronizerIfNeeded(defaults: defaults)
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults)
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .day * 15)) { (result) in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, defaults.parameters.networking.daysToCheck)
    }
}

