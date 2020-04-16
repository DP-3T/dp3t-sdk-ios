/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest

final class ExposeeServiceClientTests: XCTestCase {
    func testExposeeEmpty() {
        let json = "{\"exposed\": []}".data(using: .utf8)
        let headers = ["Etag": "HASH"]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: json, urlResponse: response, error: nil)
        let applicationDescriptor = TracingApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        let exposeeExpectation = expectation(description: "exposee")
        synchronizer.getExposee(dayIdentifier: "01.01.1970") { (result) in
            XCTAssert(session.request_!.url!.absoluteString == "http://xy.ch/v1/exposed/01.01.1970")
            switch result {
            case let .failure(error):
                XCTFail(error.localizedDescription)
            case let .success(knownCases):
                XCTAssert(knownCases != nil)
                XCTAssert(knownCases!.isEmpty)
            }
            exposeeExpectation.fulfill()
        }

        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testExposeeSingle() {
        let model = "{ \"key\": \"k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=\",\"onset\": \"2020-04-14\"}"
        let json = "{\"exposed\": [\(model)]}".data(using: .utf8)
        let headers = ["Etag": "HASH"]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: json, urlResponse: response, error: nil)
        let applicationDescriptor = TracingApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        let exposeeExpectation = expectation(description: "exposee")
        synchronizer.getExposee(dayIdentifier: "01.01.1970") { (result) in
            XCTAssert(session.request_!.url!.absoluteString == "http://xy.ch/v1/exposed/01.01.1970")
            switch result {
            case let .failure(error):
                XCTFail(error.localizedDescription)
            case let .success(knownCases):
                XCTAssert(knownCases != nil)
                XCTAssertEqual(knownCases!.first!.key.base64EncodedString(), "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=")
                XCTAssertEqual(knownCases!.first!.onset, "2020-04-14")
            }
            exposeeExpectation.fulfill()
        }

        waitForExpectations(timeout: 1) { (error) in
            XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testWithSameEtagExposeeSingle() {
        let model = "{ \"key\": \"k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=\",\"onset\": \"2020-04-14\"}"
        let json = "{\"exposed\": [\(model)]}".data(using: .utf8)
        let headers = ["Etag": "HASH"]
        //URLSession gives the cached reponse
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)!
        let session = MockSession(data: json, urlResponse: response, error: nil)
        let applicationDescriptor = TracingApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")

        let cachedResponse = CachedURLResponse(response: response, data: Data())
        let cache = MockUrlCache(response: cachedResponse)

        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session,  urlCache: cache)

        let exposeeExpectation = expectation(description: "exposee")
        synchronizer.getExposee(dayIdentifier: "01.01.1970") { (result) in
            XCTAssert(session.request_!.url!.absoluteString == "http://xy.ch/v1/exposed/01.01.1970")
            switch result {
            case let .failure(error):
                XCTFail(error.localizedDescription)
            case let .success(knownCases):
                XCTAssert(knownCases == nil)
            }
            exposeeExpectation.fulfill()
        }

        waitForExpectations(timeout: 1) { (error) in
            XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testWithDifferentEtagExposeeSingle() {
        let model = "{ \"key\": \"k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=\",\"onset\": \"2020-04-14\"}"
        let json = "{\"exposed\": [\(model)]}".data(using: .utf8)
        let headers = ["Etag": "HASH"]
        //URLSession gives the cached reponse
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)!

        let cachedHeaders = ["Etag": "HASHDIFF"]
        //URLSession gives the cached reponse
        let cachedResponse = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: cachedHeaders)!

        let session = MockSession(data: json, urlResponse: response, error: nil)
        let applicationDescriptor = TracingApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")

        let cachedCacheResponse = CachedURLResponse(response: cachedResponse, data: Data())
        let cache = MockUrlCache(response: cachedCacheResponse)

        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session,  urlCache: cache)

        let exposeeExpectation = expectation(description: "exposee")
        synchronizer.getExposee(dayIdentifier: "01.01.1970") { (result) in
            XCTAssert(session.request_!.url!.absoluteString == "http://xy.ch/v1/exposed/01.01.1970")
            switch result {
            case let .failure(error):
                XCTFail(error.localizedDescription)
            case let .success(knownCases):
                XCTAssert(knownCases != nil)
                XCTAssertEqual(knownCases!.first!.key.base64EncodedString(), "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=")
                XCTAssertEqual(knownCases!.first!.onset, "2020-04-14")
            }
            exposeeExpectation.fulfill()
        }

        waitForExpectations(timeout: 1) { (error) in
            XCTAssertNotNil(exposeeExpectation)
        }
    }

    static var allTests = [
        ("testExposeeEmpty", testExposeeEmpty),
        ("testExposeeSingle", testExposeeSingle),
        ("testWithSameEtagExposeeSingle", testWithSameEtagExposeeSingle),
        ("testWithDifferentEtagExposeeSingle", testWithDifferentEtagExposeeSingle)
    ]
}
