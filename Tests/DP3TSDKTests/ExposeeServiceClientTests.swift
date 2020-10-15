/*
* Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
*
* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at https://mozilla.org/MPL/2.0/.
*
* SPDX-License-Identifier: MPL-2.0
*/


@testable import DP3TSDK
import Foundation
import XCTest

class ExposeeServiceClientTests: XCTestCase {

    let descriptor = MockService.descriptor
    var session: MockSession!
    var mockCache: MockUrlCache!
    var client: ExposeeServiceClient!
    let parameters = Default.shared.parameters

    override func setUp() {
        session = MockSession(data: nil, urlResponse: nil, error: nil)
        mockCache = MockUrlCache(response: .init())
        client = ExposeeServiceClient(descriptor: descriptor,
                                          urlSession: session,
                                          urlCache: mockCache)
    }


    func testExposeeNolastKeyBundleTag(){
        let (request, result) = getExposeeRequest(lastKeyBundleTag: nil)
        XCTAssertEqual(request.url!.absoluteString,
                       "https://bucket.dpppt.org/v2/gaen/exposed")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            XCTAssert(error == .notHTTPResponse)
        }
    }

    func testExposeeWithlastKeyBundleTag(){
        let (request, result) = getExposeeRequest(lastKeyBundleTag: "1600560000000")
        XCTAssertEqual(request.url!.absoluteString,
                       "https://bucket.dpppt.org/v2/gaen/exposed?lastKeyBundleTag=1600560000000")
        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            XCTAssert(error == .notHTTPResponse)
        }
    }

    func testDetectTimeShiftWithDateOnly(){
        let expectedURL = URL(string: "https://bucket.dpppt.org/v2/gaen/exposed")!
        session.data = "Data".data(using: .utf8)
        let date = Date().addingTimeInterval(parameters.networking.allowedServerTimeDiff * -1)
        session.urlResponse = HTTPURLResponse(url: expectedURL,
                                              statusCode: 200,
                                              httpVersion: nil,
                                              headerFields: [
                                                "Age": "0",
                                                "date": HTTPURLResponse.dateFormatter.string(from: date)])
        let (_, result) = getExposeeRequest(lastKeyBundleTag: nil)

        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            XCTAssert(error == .timeInconsistency(shift: parameters.networking.allowedServerTimeDiff))
        }
    }

    func testDetectTimeShiftWithDateAndAgeSuceeding(){
        let expectedURL = URL(string: "https://bucket.dpppt.org/v2/gaen/exposed")!
        session.data = "Data".data(using: .utf8)
        let age: TimeInterval = 100
        let date = Date().addingTimeInterval(parameters.networking.allowedServerTimeDiff * -1)
        session.urlResponse = HTTPURLResponse(url: expectedURL,
                                              statusCode: 200,
                                              httpVersion: nil,
                                              headerFields: [
                                                "Age": "\(Int(age))",
                                                "date": HTTPURLResponse.dateFormatter.string(from: date)])
        let (_, result) = getExposeeRequest(lastKeyBundleTag: nil)

        switch result {
        case .success:
            break
        case .failure:
            XCTFail()
        }
    }

    func testDetectTimeShiftWithDateAndAgeFailing(){
        let expectedURL = URL(string: "https://bucket.dpppt.org/v2/gaen/exposed")!
        session.data = "Data".data(using: .utf8)
        let age: TimeInterval = 100
        let date = Date().addingTimeInterval((parameters.networking.allowedServerTimeDiff + age) * -1)
        session.urlResponse = HTTPURLResponse(url: expectedURL,
                                              statusCode: 200,
                                              httpVersion: nil,
                                              headerFields: [
                                                "Age": "\(Int(age))",
                                                "date": HTTPURLResponse.dateFormatter.string(from: date)])
        let (_, result) = getExposeeRequest(lastKeyBundleTag: nil)

        switch result {
        case .success:
            XCTFail()
        case let .failure(error):
            XCTAssert(error == .timeInconsistency(shift: parameters.networking.allowedServerTimeDiff + age))
        }
    }






    // MARK: Helper
    func getExposeeRequest(lastKeyBundleTag: String?) -> (URLRequest, Result<ExposeeSuccess, DP3TNetworkingError>) {
        let exp = expectation(description: "exp")
        var result: Result<ExposeeSuccess, DP3TNetworkingError>?
        let task  = client.getExposee(lastKeyBundleTag: lastKeyBundleTag) { (res) in
            result = res
            exp.fulfill()
        }
        task.resume()
        wait(for: [exp], timeout: 0.2)

        XCTAssertEqual(session.requests.count, 1)
        return (session.requests.first!, result!)
    }
}
