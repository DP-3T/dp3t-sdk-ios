/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest
import SQLite

fileprivate class MockMatcher: DP3TMatcherProtocol {
    var knownCaseKeys: [Data] = []
    func checkNewKnownCase(_ knownCase: KnownCaseModel, bucketDay: String) throws {
        knownCaseKeys.append(knownCase.key)
    }
}

final class KnownCasesSynchronizerTests: XCTestCase {

    let connection = try! Connection(.inMemory, readonly: false)

    lazy var database: DP3TDatabase! = try! DP3TDatabase(connection_: connection)

    override func tearDown() {
        try! database.emptyStorage()
    }

    func getMockService(array: String = "[]", date: Date = Date()) -> (ExposeeServiceClient, MockSession){
        let json = "{\"exposed\": \(array)}".data(using: .utf8)
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: date)]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: json, urlResponse: response, error: nil)
        let applicationDescriptor = TracingApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        return (ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session), session)
    }

    func testSyncMakesAllRequests() {

        let matcher = MockMatcher()
        let (service, session) = getMockService()
        let synchronizer = KnownCasesSynchronizer(appId: "ch.xy", database: database, matcher: matcher)
        let exposeeExpectation = expectation(description: "exposee")
        synchronizer.sync(service: service) { (result) in
            if case .success = result {
                let dayIdentifiers = (0 ..< NetworkingConstants.daysToFetch).reversed().map { days -> String in
                    let date = Calendar.current.date(byAdding: .day, value: -1 * days, to: Date())!
                    return NetworkingConstants.dayIdentifierFormatter.string(from: date)
                }

                for identifier in dayIdentifiers {
                    XCTAssert(session.requests.compactMap(\.url?.absoluteString).contains { (url) -> Bool in
                        url.contains(identifier)
                    })
                }
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
        let matcher = MockMatcher()
        let (service, _) = getMockService(array: "[{ \"key\": \"\(b64Key)\",\"onset\": \"2020-04-14\"}]")
        let synchronizer = KnownCasesSynchronizer(appId: "ch.xy", database: database, matcher: matcher)
        let exposeeExpectation = expectation(description: "exposee")
        synchronizer.sync(service: service) { (result) in

            if case .success = result {
                XCTAssertEqual(matcher.knownCaseKeys.count, 1)
                XCTAssert(matcher.knownCaseKeys.contains(Data(base64Encoded: b64Key)!))
            } else {
                XCTFail()
            }

            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testTimeIncosistencyForeward(){
        let matcher = MockMatcher()
        let timestamp = Date().addingTimeInterval(NetworkingConstants.timeShiftThreshold * (-1))
        let (service, _) = getMockService(date: timestamp)
        let synchronizer = KnownCasesSynchronizer(appId: "ch.xy", database: database, matcher: matcher)
        let exposeeExpectation = expectation(description: "exposee")
        synchronizer.sync(service: service) { (result) in
            switch result {
            case .success:
                XCTFail("Should not succeed due to timeInconsistency")
            case let .failure(error):
                switch error {
                case let .timeInconsistency(shift: shift):
                    let shiftNow = Date().timeIntervalSince(timestamp)
                    XCTAssertEqual(shiftNow, shift, accuracy: .second)
                default:
                    XCTFail("wrong error")
                }
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }
    }

    static var allTests = [
        ("testSyncMakesAllRequests", testSyncMakesAllRequests),
        ("testCallingOfMatcher", testCallingOfMatcher),
        ("testTimeIncosistencyForeward", testTimeIncosistencyForeward)
    ]
}
