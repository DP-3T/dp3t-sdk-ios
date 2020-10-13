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

final class KnownCasesSynchronizerTests: XCTestCase {
    func testInitialToday() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let now = Self.formatter.date(from: "19.05.2020 09:00")!
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: now) { res in
        XCTAssertEqual(res, SyncResult.success)
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 1)

        XCTAssertEqual(defaults.lastPublishedKeyTag, service.publishedKeyTag)
    }

    func testInitialLoadingFirstBatch() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))

        let oldKeyTag = Self.formatter.date(from: "01.05.2020 09:00")!.millisecondsSince1970
        defaults.lastPublishedKeyTag = oldKeyTag
        service.publishedKeyTag = Self.formatter.date(from: "05.05.2020 09:00")!.millisecondsSince1970
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: Self.formatter.date(from: "19.05.2020 09:00")!) { res in
            XCTAssertEqual(res, SyncResult.success)
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 1)
        XCTAssertEqual(service.requests.first!, oldKeyTag)
        XCTAssertEqual(defaults.lastPublishedKeyTag, service.publishedKeyTag)
    }

    func testRespectingRateLimitSingleDay() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))

        let today = DayDate().dayMin
        var suceesses = 0
        for i in 0 ..< 24 * 4 {
            let time = today.addingTimeInterval(Double(i) * TimeInterval.hour / 4)
            let expecation = expectation(description: "syncExpectation")
            sync.sync(now: time) { res in
                if res == .success {
                    suceesses += 1
                }
                expecation.fulfill()
            }
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(suceesses, ExposureDetectionTimingManager.maxDetections)
        XCTAssertEqual(matcher.timesCalledReceivedNewData, ExposureDetectionTimingManager.maxDetections)
    }

    func testOnlyCallingMatcherOverMultipleDays() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))

        let today = DayDate().dayMin
        let days = 3
        for i in 0 ..< 24 * days {
            let time = today.addingTimeInterval(Double(i) * TimeInterval.hour)
            let expecation = expectation(description: "syncExpectation")
            sync.sync(now: time) { _ in
                expecation.fulfill()
            }
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(matcher.timesCalledReceivedNewData, days * 6)
    }

    func testStoringLastSyncNoData() {
        let matcher = MockMatcher()
        let service = MockService()
        service.data = nil
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: Self.formatter.date(from: "19.05.2020 09:00")!) { res in
            XCTAssertEqual(res, SyncResult.success)
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 1)
        XCTAssertEqual(defaults.lastPublishedKeyTag, service.publishedKeyTag)
    }

    func testDontStoreLastSyncNetworkingError() {
        let matcher = MockMatcher()
        let service = MockService()
        service.error = .couldNotEncodeBody
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { res in
            XCTAssertEqual(res, SyncResult.failure(.networkingError(error: service.error!)))
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(defaults.lastPublishedKeyTag, service.publishedKeyTag)
    }

    func testDontStoreLastSyncMatchingError() {
        let matcher = MockMatcher()
        let service = MockService()
        matcher.error = DP3TTracingError.bluetoothTurnedOff
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { res in
            XCTAssertEqual(res, SyncResult.failure(.bluetoothTurnedOff))
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssert(defaults.lastPublishedKeyTag == nil)
    }

    func testRepeatingRequestsAfterDay() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: Self.formatter.date(from: "19.05.2020 09:00")!) { res in

            XCTAssertEqual(res, SyncResult.success)
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 1)

        service.requests = []

        let secondExpectation = expectation(description: "secondSyncExpectation")
        sync.sync(now: Self.formatter.date(from: "19.05.2020 09:00")!.addingTimeInterval(.hour + .day)) { res in
            XCTAssertEqual(res, SyncResult.success)
            secondExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 1)
        XCTAssertEqual(defaults.lastPublishedKeyTag, service.publishedKeyTag)
    }

    func testCallingSyncMulithreaded() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))

        let expecation = expectation(description: "syncExpectation")
        let iterations = 50
        expecation.expectedFulfillmentCount = iterations

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            sync.sync(now: Self.formatter.date(from: "19.05.2020 09:00")!) { res in
                XCTAssertEqual(res, SyncResult.success)
                expecation.fulfill()
            }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 1)
    }

    func testCallingSyncMulithreadedWithCancel() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))

        let exp = expectation(description: "Test after 2 seconds")
        sync.sync(now: Self.formatter.date(from: "19.05.2020 09:00")!) { result in
            switch result {
            case let .failure(error):
                switch error {
                case .cancelled:
                    break
                default:
                    XCTFail()
                }
            default:
                XCTFail()
            }
            exp.fulfill()
        }
        sync.cancelSync()

        _ = XCTWaiter.wait(for: [exp], timeout: 2.0)

        XCTAssertNotEqual(service.requests.count, 1)
        XCTAssertEqual(defaults.lastPublishedKeyTag, nil)
    }

    func testStoringOfSuccessfulDates(){
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        service.error = .HTTPFailureResponse(status: 400, data: nil)
        service.errorAfter = 0
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: Self.formatter.date(from: "19.05.2020 09:00")!) { res in
            XCTAssertEqual(res, SyncResult.failure(.networkingError(error: service.error!)))
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 1)

        XCTAssert(defaults.lastPublishedKeyTag == nil)
    }

    static var formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy HH:mm"
        return df
    }()
}
