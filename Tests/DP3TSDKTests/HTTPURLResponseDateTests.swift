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
import XCTest

class HTTPURLResponseDateTests: XCTestCase {

    func testDateParsing() {
        let response = HTTPURLResponse(url: URL(string: "http://dpppt.org")!, statusCode: 200, httpVersion: nil, headerFields: ["date": "Mon, 22 Jun 2020 07:30:50 GMT"])!
        let date = response.date!
        XCTAssertEqual(date.timeIntervalSince1970, 1592811050)
    }

    func testAgeParsing(){
        let response =  HTTPURLResponse(url: URL(string: "http://dpppt.org")!, statusCode: 200, httpVersion: nil, headerFields: ["age": "24"])!
        XCTAssertEqual(response.age, 24)
    }

}
