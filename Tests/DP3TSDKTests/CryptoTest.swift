/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest

private class KeyStore: SecureStorageProtocol {
    var keys: [SecretKey] = []

    var ephIDs: EphIDsForDay?

    func getSecretKeys() throws -> [SecretKey] {
        return keys
    }

    func setSecretKeys(_ object: [SecretKey]) throws {
        keys = object
    }

    func getEphIDs() throws -> EphIDsForDay? {
        return ephIDs
    }

    func setEphIDs(_ object: EphIDsForDay) throws {
        ephIDs = object
    }

    func removeAllObject() {
        keys = []
        ephIDs = nil
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

    func testGenerateEphIDs() {
        let store = KeyStore()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)
        let allEphsOfToday = try! DP3TCryptoModule.createEphIDs(secretKey: crypto.getSecretKeyForPublishing(onsetDate: Date())!)
        let currentEphID = try! crypto.getCurrentEphID()
        var matchingCount = 0
        for ephID in allEphsOfToday {
            XCTAssert(ephID.count == CryptoConstants.keyLenght)
            if ephID == currentEphID {
                matchingCount += 1
            }
        }
        XCTAssert(matchingCount == 1)
    }

    func testStorageEphIDs() {
        let store = KeyStore()
        let crypto: DP3TCryptoModule = try! DP3TCryptoModule(store: store)
        let currentEphID = try! crypto.getCurrentEphID()
        XCTAssertNotNil(store.ephIDs)
        XCTAssertTrue(store.ephIDs!.ephIDs.contains(currentEphID))
        XCTAssertEqual(currentEphID, try! crypto.getCurrentEphID())
    }

    func testGenerationEphsIdsWithAndorid() {
        let base64SecretKey = "BLz13+/lzSyPbNw4SoGvjjNynqh125AQEQup+FDelG0="
        let base64EncodedEphID = "0lzW4z8mj+MPdZk8UaK9jA=="
        let base64EncodedEph1Id = "Vq+p4jkSaDbhib6dfgsHGw=="
        let allEphID: [Data] = try! DP3TCryptoModule.createEphIDs(secretKey: Data(base64Encoded: base64SecretKey)!)
        var matchingCount = 0
        for ephID in allEphID {
            if ephID.base64EncodedString() == base64EncodedEphID {
                matchingCount += 1
            }
            if ephID.base64EncodedString() == base64EncodedEph1Id {
                matchingCount += 1
            }
        }
        XCTAssert(matchingCount == 2)
    }

    func testReset() {
        let store = KeyStore()
        var crypto: DP3TCryptoModule? = try! DP3TCryptoModule(store: store)
        let ephID = try! crypto!.getCurrentEphID()

        crypto!.reset()
        crypto = nil
        crypto = try! DP3TCryptoModule(store: store)

        let newEphID = try! crypto!.getCurrentEphID()

        XCTAssertNotEqual(ephID, newEphID)
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
        let crypto1: DP3TCryptoModule = try! DP3TCryptoModule(store: store1)
        let token = try! crypto1.getCurrentEphID()
        _ = try! crypto1.getCurrentSK(day: SecretKeyDay(date: Date().addingTimeInterval(1 * .day)))
        _ = try! crypto1.getCurrentSK(day: SecretKeyDay(date: Date().addingTimeInterval(2 * .day)))
        _ = try! crypto1.getCurrentSK(day: SecretKeyDay(date: Date().addingTimeInterval(3 * .day)))

        let key = (try! crypto1.getSecretKeyForPublishing(onsetDate: Date()))!

        var handshakes: [HandshakeModel] = []
        handshakes.append(HandshakeModel(identifier: 0, timestamp: Date(), ephID: token, TXPowerlevel: nil, RSSI: nil, knownCaseId: nil))

        let store2 = KeyStore()
        let crypto2: DP3TCryptoModule = try! DP3TCryptoModule(store: store2)

        let h = try! crypto2.checkContacts(secretKey: key, onsetDate: SecretKeyDay(date: Date()), bucketDate: SecretKeyDay(date: Date().addingTimeInterval(.day)), getHandshake: { (_) -> ([HandshakeModel]) in
            handshakes
        })

        XCTAssertNotNil(h)
    }

    func testSecretKeyPushlishingOnsetAfterContact() {
        let store1 = KeyStore()
        let crypto1: DP3TCryptoModule = try! DP3TCryptoModule(store: store1)
        let token = try! crypto1.getCurrentEphID()
        _ = try! crypto1.getCurrentSK(day: SecretKeyDay(date: Date().addingTimeInterval(1 * .day)))
        _ = try! crypto1.getCurrentSK(day: SecretKeyDay(date: Date().addingTimeInterval(2 * .day)))
        _ = try! crypto1.getCurrentSK(day: SecretKeyDay(date: Date().addingTimeInterval(3 * .day)))

        let key = (try! crypto1.getSecretKeyForPublishing(onsetDate: Date().addingTimeInterval(.day)))!

        var handshakes: [HandshakeModel] = []
        handshakes.append(HandshakeModel(identifier: 0, timestamp: Date(), ephID: token, TXPowerlevel: nil, RSSI: nil, knownCaseId: nil))

        let store2 = KeyStore()
        let crypto2: DP3TCryptoModule = try! DP3TCryptoModule(store: store2)

        let h = try! crypto2.checkContacts(secretKey: key, onsetDate: SecretKeyDay(date: Date()), bucketDate: SecretKeyDay(date: Date().addingTimeInterval(.day)), getHandshake: { (_) -> ([HandshakeModel]) in
            handshakes
        })

        XCTAssertNil(h)
    }

    func testKeyAndTokenToday(_ key: String, _ token: String, found: Bool) {
        let store = KeyStore()
        let crypto: DP3TCryptoModule? = try! DP3TCryptoModule(store: store)

        var handshakes: [HandshakeModel] = []
        handshakes.append(HandshakeModel(identifier: 0, timestamp: Date(), ephID: Data(base64Encoded: token)!, TXPowerlevel: nil, RSSI: nil, knownCaseId: nil))

        let keyData = Data(base64Encoded: key)!
        let h = try! crypto?.checkContacts(secretKey: keyData, onsetDate: SecretKeyDay(date: Date().addingTimeInterval(-1 * .day)), bucketDate: SecretKeyDay(), getHandshake: { (_) -> ([HandshakeModel]) in
            handshakes
        })
        XCTAssertEqual(h != nil, found)
    }

    static var allTests = [
        ("sha256", testSha256),
        ("generateEphIDs", testGenerateEphIDs),
        ("generateEphIDsAndroid", testGenerationEphsIdsWithAndorid),
        ("testHmac", testHmac),
        ("testReset", testReset),
        ("testTokenToday", testTokenToday),
        ("testWrongTokenToday", testWrongTokenToday),
        ("testSecretKeyPushlishing", testSecretKeyPushlishing),
        ("testSecretKeyPushlishingOnsetAfterContact", testSecretKeyPushlishingOnsetAfterContact),
        ("testStorageEphIDs", testStorageEphIDs),
    ]
}
