/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest

final class ExposeeServiceClientTests: XCTestCase {
    func testExposeeEmpty() {
        let batchTimestamp = Date()
        var list = ProtoExposedList()
        list.batchReleaseTime = batchTimestamp.millisecondsSince1970
        let data = try! list.serializedData()
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: Date())]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: data, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", jwtPublicKey: nil, bucketBaseUrl: URL(string: "http://xy.ch")!, reportBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        let result = synchronizer.getExposeeSynchronously(batchTimestamp: batchTimestamp)

        let timestampIdentifier = String(batchTimestamp.millisecondsSince1970)
        XCTAssert(session.requests.compactMap(\.url?.absoluteString).contains("http://xy.ch/v1/exposed/\(timestampIdentifier)"))
        switch result {
        case let .failure(error):
            XCTFail(error.localizedDescription)
        case let .success(knownCases):
            XCTAssert(knownCases != nil)
            XCTAssert(knownCases!.isEmpty)
        }
    }

    func testExposeeSingle() {
        let onset = Date().addingTimeInterval(10000)
        let batchTimestamp = Date()
        var list = ProtoExposedList()
        list.batchReleaseTime = batchTimestamp.millisecondsSince1970
        var exposee = ProtoExposee()
        exposee.key = Data(base64Encoded: "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=")!
        exposee.keyDate = onset.millisecondsSince1970
        list.exposed.append(exposee)
        let data = try! list.serializedData()
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: Date())]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: data, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", jwtPublicKey: nil, bucketBaseUrl: URL(string: "http://xy.ch")!, reportBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        let result = synchronizer.getExposeeSynchronously(batchTimestamp: batchTimestamp)
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
    }

    func testWithDifferentEtagExposeeSingle() {
        let onset = Date().addingTimeInterval(10000)
        let batchTimestamp = Date()
        var list = ProtoExposedList()
        list.batchReleaseTime = batchTimestamp.millisecondsSince1970
        var exposee = ProtoExposee()
        exposee.key = Data(base64Encoded: "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI=")!
        exposee.keyDate = onset.millisecondsSince1970
        list.exposed.append(exposee)
        let data = try! list.serializedData()

        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: Date())]
        // URLSession gives the cached reponse
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)!

        let cachedHeaders = ["Etag": "HASHDIFF"]
        // URLSession gives the cached reponse
        let cachedResponse = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: cachedHeaders)!

        let session = MockSession(data: data, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", jwtPublicKey: nil, bucketBaseUrl: URL(string: "http://xy.ch")!, reportBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")

        let cachedCacheResponse = CachedURLResponse(response: cachedResponse, data: Data())
        let cache = MockUrlCache(response: cachedCacheResponse)

        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session, urlCache: cache)

        let result = synchronizer.getExposeeSynchronously(batchTimestamp: batchTimestamp)
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
    }

    /*func testTimeInconsistency() {
        let timeStamp = Date().addingTimeInterval(NetworkingConstants.timeShiftThreshold * (-1))
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: timeStamp)]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: Data(), urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", jwtPublicKey: nil, bucketBaseUrl: URL(string: "http://xy.ch")!, reportBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        let batchTimestamp = Date()
        let result = synchronizer.getExposeeSynchronously(batchTimestamp: batchTimestamp)
        switch result {
        case let .failure(error):
            switch error {
            case let .timeInconsistency(shift: shift):
                let shiftNow = Date().timeIntervalSince(timeStamp)
                XCTAssertEqual(shiftNow, shift, accuracy: .second)
            default:
                XCTFail("Should not succeed due to timeInconsistency")
            }
        case .success:
            XCTFail("Should not succeed due to timeInconsistency")
        }
    }*/

    func testSettingAcceptHeaderProtobuf() {
        let batchTimestamp = Date()
        var list = ProtoExposedList()
        list.batchReleaseTime = batchTimestamp.millisecondsSince1970
        let data = try! list.serializedData()
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: Date())]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: data, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", jwtPublicKey: nil, bucketBaseUrl: URL(string: "http://xy.ch")!, reportBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        let synchronizer = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session)

        _ = synchronizer.getExposeeSynchronously(batchTimestamp: batchTimestamp)
        let responseHeaders = session.requests.first!.allHTTPHeaderFields!
        XCTAssertEqual(responseHeaders["Accept"]!, "application/x-protobuf")
    }

    static var allTests = [
        ("testExposeeEmpty", testExposeeEmpty),
        ("testExposeeSingle", testExposeeSingle),
        ("testWithDifferentEtagExposeeSingle", testWithDifferentEtagExposeeSingle),
        ("testSettingAcceptHeaderProtobuf", testSettingAcceptHeaderProtobuf),
    ]
}
