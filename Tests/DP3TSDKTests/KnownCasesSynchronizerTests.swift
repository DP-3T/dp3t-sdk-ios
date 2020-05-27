/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

@testable import DP3TSDK
import Foundation
import XCTest

private class MockMatcher: Matcher {
    var delegate: MatcherDelegate?

    var error: Error?

    func receivedNewKnownCaseData(_: Data, keyDate _: Date) throws {}

    func finalizeMatchingSession() throws {
        if let error = error {
            throw error
        }
    }
}

private class MockService: ExposeeServiceClientProtocol {
    var requests: [Date] = []
    let session = MockSession(data: "Data".data(using: .utf8), urlResponse: nil, error: nil)
    let queue = DispatchQueue(label: "synchronous")
    var error: DP3TNetworkingError?
    var publishedUntil: Date = .init()
    var data: Data? = "Data".data(using: .utf8)

    func getExposee(batchTimestamp: Date, completion: @escaping (Result<ExposeeSuccess, DP3TNetworkingError>) -> Void) -> URLSessionDataTask {
        return session.dataTask(with: .init(url: URL(string: "http://www.google.com")!)) { _, _, _ in
            if let error = self.error {
                completion(.failure(error))
            } else {
                self.queue.sync {
                    self.requests.append(batchTimestamp)
                }
                completion(.success(.init(data: self.data, publishedUntil: .init())))
            }
        }
    }

    func addExposeeList(_: ExposeeListModel, authentication _: ExposeeAuthMethod, completion _: @escaping (Result<OutstandingPublish, DP3TNetworkingError>) -> Void) {}

    func addDelayedExposeeList(_: DelayedKeyModel, token _: String?, completion _: @escaping (Result<Void, DP3TNetworkingError>) -> Void) {}
}

final class KnownCasesSynchronizerTests: XCTestCase {
    func testInitialToday() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 10)
        XCTAssert(service.requests.contains(DayDate().dayMin))
        XCTAssert(!defaults.publishedAfterStore.isEmpty)
    }

    func testInitialLoadingFirstBatch() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 10)
        XCTAssertEqual(defaults.publishedAfterStore.count, 10)
    }

    func testStoringPublishedAfterNoData() {
        let matcher = MockMatcher()
        let service = MockService()
        service.data = nil
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 10)
        XCTAssertEqual(defaults.publishedAfterStore.count, 10)
    }

    func testInitialLoadingManyBatches() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .day * 15)) { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, defaults.parameters.networking.daysToCheck)
        XCTAssertEqual(defaults.publishedAfterStore.count, defaults.parameters.networking.daysToCheck)
    }

    func testDontStorePublishedAfterNetworkingError() {
        let matcher = MockMatcher()
        let service = MockService()
        service.error = .couldNotEncodeBody
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssert(defaults.publishedAfterStore.isEmpty)
    }

    func testDontStorePublishedAfterMatchingError() {
        let matcher = MockMatcher()
        let service = MockService()
        matcher.error = DP3TTracingError.bluetoothTurnedOff
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssert(defaults.publishedAfterStore.isEmpty)
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
        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 10)
        XCTAssertEqual(defaults.publishedAfterStore.count, 10)

        service.requests = []

        let secondExpectation = expectation(description: "secondSyncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour + .day)) { _ in
            secondExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 10)
        XCTAssertEqual(defaults.publishedAfterStore.count, 10)
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
            sync.sync(now: .init(timeIntervalSinceNow: .hour)) { _ in
                expecation.fulfill()
            }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 10)
        XCTAssertEqual(defaults.publishedAfterStore.count, 10)
    }

    func testCallingSyncMulithreadedWithCancel() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults,
                                          descriptor: .init(appId: "ch.dpppt", bucketBaseUrl: URL(string: "http://www.google.de")!, reportBaseUrl: URL(string: "http://www.google.de")!))

        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { result in
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
        }
        sync.cancelSync()

        let exp = expectation(description: "Test after 2 seconds")
        _ = XCTWaiter.wait(for: [exp], timeout: 2.0)

        XCTAssertNotEqual(service.requests.count, 10)
        XCTAssertNotEqual(defaults.publishedAfterStore.count, 10)
    }

    func testLastDesiredSyncTimeNoon() {
        let defaults = MockDefaults()
        let input = Self.formatter.date(from: "19.05.2020 12:12")!
        let output = Self.formatter.date(from: "19.05.2020 0\(defaults.parameters.networking.syncHourMorning):00")!
        XCTAssertEqual(KnownCasesSynchronizer.getLastDesiredSyncTime(ts: input, defaults: defaults), output)
    }

    func testLastDesiredSyncTimeYesterday() {
        let defaults = MockDefaults()
        let input = Self.formatter.date(from: "19.05.2020 05:55")!
        let output = Self.formatter.date(from: "18.05.2020 \(defaults.parameters.networking.syncHourEvening):00")!
        XCTAssertEqual(KnownCasesSynchronizer.getLastDesiredSyncTime(ts: input), output)
    }

    func testLastDesiredSyncTimeNight() {
        let defaults = MockDefaults()
        let input = Self.formatter.date(from: "19.05.2020 23:55")!
        let output = Self.formatter.date(from: "19.05.2020 \(defaults.parameters.networking.syncHourEvening):00")!
        XCTAssertEqual(KnownCasesSynchronizer.getLastDesiredSyncTime(ts: input), output)
    }

    static var formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy HH:mm"
        return df
    }()
}
