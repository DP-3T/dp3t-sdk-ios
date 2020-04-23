/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest


final class ExposeeServiceClientTests: XCTestCase {
    func testExposeeEmpty() {
        let list = ProtoExposedList()
        let data = try! list.serializedData()
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: Date())]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: data, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        let exposeeExpectation = expectation(description: "exposee")
        let batchTimestamp = Date()
        synchronizer.getExposee(batchTimestamp: batchTimestamp) { (result) in
            let timestampIdentifier = String(batchTimestamp.millisecondsSince1970)
            XCTAssert(session.requests.compactMap(\.url?.absoluteString).contains("http://xy.ch/v1/exposed/\(timestampIdentifier)"))
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
        let onset = Date().addingTimeInterval(10000)
        var list = ProtoExposedList()
        var exposee = ProtoExposee()
        exposee.key = Data(base64Encoded: "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=")!
        exposee.onset = onset.millisecondsSince1970
        list.exposed.append(exposee)
        let data = try! list.serializedData()
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: Date())]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: data, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        let exposeeExpectation = expectation(description: "exposee")
        let batchTimestamp = Date()
        synchronizer.getExposee(batchTimestamp: batchTimestamp) { (result) in
            let timestampIdentifier = String(batchTimestamp.millisecondsSince1970)
            XCTAssert(session.requests.compactMap(\.url?.absoluteString).contains("http://xy.ch/v1/exposed/\(timestampIdentifier)"))
            switch result {
            case let .failure(error):
                XCTFail(error.localizedDescription)
            case let .success(knownCases):
                XCTAssert(knownCases != nil)
                XCTAssertEqual(knownCases!.first!.key.base64EncodedString(), "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=")
                XCTAssertEqual(Int(knownCases!.first!.onset.timeIntervalSince1970), Int(onset.timeIntervalSince1970))
            }
            exposeeExpectation.fulfill()
        }

        waitForExpectations(timeout: 1) { (error) in
            XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testWithSameEtagExposeeSingle() {
        let onset = Date().addingTimeInterval(10000)
        var list = ProtoExposedList()
        var exposee = ProtoExposee()
        exposee.key = Data(base64Encoded: "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=")!
        exposee.onset = onset.millisecondsSince1970
        list.exposed.append(exposee)
        let data = try! list.serializedData()

        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: Date())]
        //URLSession gives the cached reponse
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)!
        let session = MockSession(data: data, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")

        let cachedResponse = CachedURLResponse(response: response, data: Data())
        let cache = MockUrlCache(response: cachedResponse)

        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session,  urlCache: cache)

        let exposeeExpectation = expectation(description: "exposee")
        let batchTimestamp = Date()
        synchronizer.getExposee(batchTimestamp: batchTimestamp) { (result) in
            let timestampIdentifier = String(batchTimestamp.millisecondsSince1970)
            XCTAssert(session.requests.compactMap(\.url?.absoluteString).contains("http://xy.ch/v1/exposed/\(timestampIdentifier)"))
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
        let onset = Date().addingTimeInterval(10000)
        var list = ProtoExposedList()
        var exposee = ProtoExposee()
        exposee.key = Data(base64Encoded: "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=")!
        exposee.onset = onset.millisecondsSince1970
        list.exposed.append(exposee)
        let data = try! list.serializedData()

        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: Date())]
        //URLSession gives the cached reponse
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)!

        let cachedHeaders = ["Etag": "HASHDIFF"]
        //URLSession gives the cached reponse
        let cachedResponse = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: cachedHeaders)!

        let session = MockSession(data: data, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")

        let cachedCacheResponse = CachedURLResponse(response: cachedResponse, data: Data())
        let cache = MockUrlCache(response: cachedCacheResponse)

        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session,  urlCache: cache)

        let exposeeExpectation = expectation(description: "exposee")
        let batchTimestamp = Date()
        synchronizer.getExposee(batchTimestamp: batchTimestamp) { (result) in
            let timestampIdentifier = String(batchTimestamp.millisecondsSince1970)
            XCTAssert(session.requests.compactMap(\.url?.absoluteString).contains("http://xy.ch/v1/exposed/\(timestampIdentifier)"))
            switch result {
            case let .failure(error):
                XCTFail(error.localizedDescription)
            case let .success(knownCases):
                XCTAssert(knownCases != nil)
                XCTAssertEqual(knownCases!.first!.key.base64EncodedString(), "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=")
                XCTAssertEqual(Int(knownCases!.first!.onset.timeIntervalSince1970), Int(onset.timeIntervalSince1970))
            }
            exposeeExpectation.fulfill()
        }

        waitForExpectations(timeout: 1) { (error) in
            XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testTimeInconsistency() {
        let json = "{\"exposed\": []}".data(using: .utf8)
        let timeStamp = Date().addingTimeInterval(NetworkingConstants.timeShiftThreshold * (-1))
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: timeStamp)]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: json, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        let exposeeExpectation = expectation(description: "exposee")
        let batchTimestamp = Date()
        synchronizer.getExposee(batchTimestamp: batchTimestamp) { (result) in
            switch result {
            case let .failure(error):
                switch error {
                case let .timeInconsistency(shift: shift):
                    let shiftNow = Date().timeIntervalSince(timeStamp)
                    XCTAssertEqual(shiftNow, shift, accuracy: .second)
                default:
                    XCTFail("Should not succeed due to timeInconsistency")
                }
            case .success(_):
                XCTFail("Should not succeed due to timeInconsistency")
            }
            exposeeExpectation.fulfill()
        }

        waitForExpectations(timeout: 1) { (error) in
            XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testSettingAcceptHeaderProtobuf() {
        let json = "{\"exposed\": []}".data(using: .utf8)
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: Date())]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: json, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", backendBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        let exposeeExpectation = expectation(description: "exposee")
        let batchTimestamp = Date()
        synchronizer.getExposee(batchTimestamp: batchTimestamp) { (result) in
            let headers = session.requests.first!.allHTTPHeaderFields!
            XCTAssertEqual(headers["Accept"]!, "application/x-protobuf")
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
        ("testWithDifferentEtagExposeeSingle", testWithDifferentEtagExposeeSingle),
        ("testTimeInconsistency", testTimeInconsistency),
        ("testSettingAcceptHeaderProtobuf", testSettingAcceptHeaderProtobuf)
    ]
}

