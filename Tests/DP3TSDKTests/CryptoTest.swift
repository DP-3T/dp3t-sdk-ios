/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
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

    func testHmac() {
        let secretKey = "9/hoU2yirCdM0oaIVNud3QjVGZhirVrprZXWXpHO434="
        let secretKeyData = Data(base64Encoded: secretKey)!
        let expected = "bwCagl624aXDNTo2VamCCaJ3+nDhX6Ss2TDmtiTX7TE="
        let real = Crypto.hmac(msg: Default.shared.parameters.crypto.broadcastKey, key: secretKeyData)
        XCTAssertEqual(real.base64EncodedString(), expected)
    }

    static var allTests = [
        ("sha256", testSha256),
        ("testHmac", testHmac),
    ]
}
