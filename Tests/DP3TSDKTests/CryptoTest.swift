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

final class DP3TTracingCryptoTests: XCTestCase {
    func testSha256() {
        let string = "COVID19"
        let strData = string.data(using: .utf8)!
        let digest = Crypto.sha256(strData)
        let hex = digest.base64EncodedString()
        XCTAssertEqual(hex, "wdvvalTpy3jExBEyO6iIHps+HUsrnwgCtMGpi86eq4c=")
    }

    func testRandomKeyGeneration() {
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            try! XCTAssertNotEqual(Crypto.generateRandomKey(), Crypto.generateRandomKey())
        }
    }
}
