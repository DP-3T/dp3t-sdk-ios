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

    func receivedNewKnownCaseData(_: Data, keyDate _: Date) throws {}

    func finalizeMatchingSession() throws {}
}

private class MockService: ExposeeServiceClientProtocol {
    var requests: [Date] = []
    let queue = DispatchQueue(label: "synchronous")
    func getExposeeSynchronously(batchTimestamp: Date, publishedAfter _: Date?) -> Result<ExposeeSuccess?, DP3TNetworkingError> {
        queue.sync {
            self.requests.append(batchTimestamp)
        }
        return .success(.init(data: "\(batchTimestamp.timeIntervalSince1970)".data(using: .utf8)!, publishedUntil: batchTimestamp))
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
                                          defaults: defaults)
        let expecation = expectation(description: "syncExpectation")
        sync.sync { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 10)
        XCTAssert(service.requests.contains(DayDate().dayMin))
    }

    func testInitialLoadingFirstBatch() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults)
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .hour)) { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, 10)
    }

    func testInitialLoadingManyBatches() {
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let sync = KnownCasesSynchronizer(matcher: matcher,
                                          service: service,
                                          defaults: defaults)
        let expecation = expectation(description: "syncExpectation")
        sync.sync(now: .init(timeIntervalSinceNow: .day * 15)) { _ in
            expecation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(service.requests.count, defaults.parameters.networking.daysToCheck)
    }

    func testLastDesiredSyncTimeNoon() {
        let input = Self.formatter.date(from: "19.05.2020 12:12")!
        let output = Self.formatter.date(from: "19.05.2020 06:00")!
        XCTAssertEqual(KnownCasesSynchronizer.getLastDesiredSyncTime(ts: input), output)
    }

    func testLastDesiredSyncTimeYesterday() {
        let input = Self.formatter.date(from: "19.05.2020 05:55")!
        let output = Self.formatter.date(from: "18.05.2020 20:00")!
        XCTAssertEqual(KnownCasesSynchronizer.getLastDesiredSyncTime(ts: input), output)
    }

    func testLastDesiredSyncTimeNight() {
        let input = Self.formatter.date(from: "19.05.2020 23:55")!
        let output = Self.formatter.date(from: "19.05.2020 20:00")!
        XCTAssertEqual(KnownCasesSynchronizer.getLastDesiredSyncTime(ts: input), output)
    }

    static var formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy HH:mm"
        df.timeZone = TimeZone(abbreviation: "UTC")!
        return df
    }()
}
