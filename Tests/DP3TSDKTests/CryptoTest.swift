/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest

private class KeyStore: SecureStorageProtocol {
    var keys: [SecretKey] = []

    var ephIds: EphIdsForDay?

    func getSecretKeys() throws -> [SecretKey] {
        return keys
    }

    func setSecretKeys(_ object: [SecretKey]) throws {
        keys = object
    }

    func getEphIds() throws -> EphIdsForDay? {
        return ephIds
    }

    func setEphIds(_ object: EphIdsForDay) throws {
        ephIds = object
    }

    func removeAllObject() {
        keys = []
        ephIds = nil
    }
}

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
        let real = Crypto.hmac(msg: CryptoConstants.broadcastKey, key: secretKeyData)
        XCTAssertEqual(real.base64EncodedString(), expected)
    }

    func testGenerateEphIds() {
        let store = KeyStore()
        let crypto: DP3TCryptoModule = DP3TCryptoModule(store: store)!
        let allEphsOfToday = try! crypto.createEphIds(secretKey: crypto.getSecretKeyForPublishing(onsetDate: Date())!)
        let currentEphId = try! crypto.getCurrentEphId()
        var matchingCount = 0
        for ephId in allEphsOfToday {
            XCTAssert(ephId.count == CryptoConstants.keyLenght)
            if ephId == currentEphId {
                matchingCount += 1
            }
        }
        XCTAssert(matchingCount == 1)
    }

    func testStorageEphIds() {
        let store = KeyStore()
        let crypto: DP3TCryptoModule = DP3TCryptoModule(store: store)!
        let currentEphId = try! crypto.getCurrentEphId()
        XCTAssertNotNil(store.ephIds)
        XCTAssertTrue(store.ephIds!.ephIds.contains(currentEphId))
        XCTAssertEqual(currentEphId, try! crypto.getCurrentEphId())
    }

    func testGenerationEphsIdsWithAndorid() {
        let store = KeyStore()
        let crypto: DP3TCryptoModule = DP3TCryptoModule(store: store)!
        let base64SecretKey = "BLz13+/lzSyPbNw4SoGvjjNynqh125AQEQup+FDelG0="
        let base64EncodedEphId = "0lzW4z8mj+MPdZk8UaK9jA=="
        let base64EncodedEph1Id = "Vq+p4jkSaDbhib6dfgsHGw=="
        let allEphId: [Data] = try! crypto.createEphIds(secretKey: Data(base64Encoded: base64SecretKey)!)
        var matchingCount = 0
        for ephId in allEphId {
            if ephId.base64EncodedString() == base64EncodedEphId {
                matchingCount += 1
            }
            if ephId.base64EncodedString() == base64EncodedEph1Id {
                matchingCount += 1
            }
        }
        XCTAssert(matchingCount == 2)
    }

    func testReset() {
        let store = KeyStore()
        var crypto: DP3TCryptoModule? = DP3TCryptoModule(store: store)!
        let ephId = try! crypto!.getCurrentEphId()

        crypto!.reset()
        crypto = nil
        crypto = DP3TCryptoModule(store: store)!

        let newEphId = try! crypto!.getCurrentEphId()

        XCTAssertNotEqual(ephId, newEphId)
    }

    func testTokenToday() {
        let key = "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs="
        let token = "ZN5cLwKOJVAWC7caIHskog=="
        testKeyAndTokenToday(key, token, found: true)
    }

    func testWrongTokenToday() {
        let key = "yJNfwAP8UaF+BZKbUiVwhUghLz60SOqPE0I="
        let token = "lTSYc/ER08HD1/ucwBJOiDLDEYiJruKqTHCiOFavzwA="
        testKeyAndTokenToday(key, token, found: false)
    }

    func testSecretKeyPushlishing() {
        let store1 = KeyStore()
        let crypto1: DP3TCryptoModule = DP3TCryptoModule(store: store1)!
        let token = try! crypto1.getCurrentEphId()
        _ = try! crypto1.getCurrentSK(day: Epoch(date: Date().addingTimeInterval(1 * .day)))
        _ = try! crypto1.getCurrentSK(day: Epoch(date: Date().addingTimeInterval(2 * .day)))
        _ = try! crypto1.getCurrentSK(day: Epoch(date: Date().addingTimeInterval(3 * .day)))

        let key = (try! crypto1.getSecretKeyForPublishing(onsetDate: Date()))!

        var handshakes: [HandshakeModel] = []
        handshakes.append(HandshakeModel(identifier: 0, timestamp: Date(), ephid: token, TXPowerlevel: nil, RSSI: nil, knownCaseId: nil))

        let store2 = KeyStore()
        let crypto2: DP3TCryptoModule = DP3TCryptoModule(store: store2)!

        let h = try! crypto2.checkContacts(secretKey: key, onsetDate: Epoch(date: Date()), bucketDate: Epoch(date: Date().addingTimeInterval(.day)), getHandshake: { (_) -> ([HandshakeModel]) in
            handshakes
        })

        XCTAssertNotNil(h)
    }

    func testSecretKeyPushlishingOnsetAfterContact() {
        let store1 = KeyStore()
        let crypto1: DP3TCryptoModule = DP3TCryptoModule(store: store1)!
        let token = try! crypto1.getCurrentEphId()
        _ = try! crypto1.getCurrentSK(day: Epoch(date: Date().addingTimeInterval(1 * .day)))
        _ = try! crypto1.getCurrentSK(day: Epoch(date: Date().addingTimeInterval(2 * .day)))
        _ = try! crypto1.getCurrentSK(day: Epoch(date: Date().addingTimeInterval(3 * .day)))

        let key = (try! crypto1.getSecretKeyForPublishing(onsetDate: Date().addingTimeInterval(.day)))!

        var handshakes: [HandshakeModel] = []
        handshakes.append(HandshakeModel(identifier: 0, timestamp: Date(), ephid: token, TXPowerlevel: nil, RSSI: nil, knownCaseId: nil))

        let store2 = KeyStore()
        let crypto2: DP3TCryptoModule = DP3TCryptoModule(store: store2)!

        let h = try! crypto2.checkContacts(secretKey: key, onsetDate: Epoch(date: Date()), bucketDate: Epoch(date: Date().addingTimeInterval(.day)), getHandshake: { (_) -> ([HandshakeModel]) in
            handshakes
        })

        XCTAssertNil(h)
    }

    func testKeyAndTokenToday(_ key: String, _ token: String, found: Bool) {
        let store = KeyStore()
        let crypto: DP3TCryptoModule? = DP3TCryptoModule(store: store)!

        var handshakes: [HandshakeModel] = []
        handshakes.append(HandshakeModel(identifier: 0, timestamp: Date(), ephid: Data(base64Encoded: token)!, TXPowerlevel: nil, RSSI: nil, knownCaseId: nil))

        let keyData = Data(base64Encoded: key)!
        let h = try! crypto?.checkContacts(secretKey: keyData, onsetDate: Epoch(date: Date().addingTimeInterval(-1 * .day)), bucketDate: Epoch(), getHandshake: { (_) -> ([HandshakeModel]) in
            handshakes
        })
        XCTAssertEqual(h != nil, found)
    }

    static var allTests = [
        ("sha256", testSha256),
        ("generateEphIds", testGenerateEphIds),
        ("generateEphIdsAndroid", testGenerationEphsIdsWithAndorid),
        ("testHmac", testHmac),
        ("testReset", testReset),
        ("testTokenToday", testTokenToday),
        ("testWrongTokenToday", testWrongTokenToday),
        ("testSecretKeyPushlishing", testSecretKeyPushlishing),
        ("testSecretKeyPushlishingOnsetAfterContact", testSecretKeyPushlishingOnsetAfterContact),
        ("testStorageEphIds", testStorageEphIds),
    ]
}
