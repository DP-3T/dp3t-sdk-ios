/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest
import SQLite

final class DatabaseTests: XCTestCase {

    let connection = try! Connection(.inMemory, readonly: false)

    lazy var database: DP3TDatabase! = try! DP3TDatabase(connection_: connection)

    override func tearDown() {
        try! database.emptyStorage()
    }

    func testEmptyStorage(){
        let date = Date()
        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!
        let h1 = HandshakeModel(identifier: nil, timestamp: date, ephID: token, TXPowerlevel: nil, RSSI: -30)
        try! database.handshakesStorage.add(handshake: h1)

        try! database.emptyStorage()

        let h = try! database.handshakesStorage.getAll()
        XCTAssertTrue(h.isEmpty)
    }

    func testContactGeneration() {
        let date = Date().addingTimeInterval(-.day)
        let day = DayDate(date: date)
        let epochStart = DP3TCryptoModule.getEpochStart(timestamp: date)

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!
        let h1 = HandshakeModel(identifier: nil,
                                timestamp: epochStart.addingTimeInterval(1),
                                ephID: token,
                                TXPowerlevel: nil,
                                RSSI: -30)

        try! database.handshakesStorage.add(handshake: h1)

        let h2 = HandshakeModel(identifier: nil,
                                timestamp: epochStart.addingTimeInterval(2 * .minute),
                                ephID: token,
                                TXPowerlevel: nil,
                                RSSI: -30)
        try! database.handshakesStorage.add(handshake: h2)

        try! database.generateContactsFromHandshakes()

        let bucketStart = epochStart.timeIntervalSince1970 - epochStart.timeIntervalSince1970.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)

        let c = try! database.contactsStorage.getContacts(for: day)
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c.first!.ephID, token)
        XCTAssertEqual(c.first!.date, Date(timeIntervalSince1970: bucketStart))
    }

    func testContactGenerationUnique() {
        let ts = DP3TCryptoModule.getEpochStart().addingTimeInterval(-CryptoConstants.secondsPerEpoch)
        let day = DayDate(date: ts)


        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!
        let h1 = HandshakeModel(identifier: nil, timestamp: ts, ephID: token, TXPowerlevel: nil, RSSI: -30)
        let h2 = HandshakeModel(identifier: nil, timestamp: ts.addingTimeInterval(10), ephID: token, TXPowerlevel: nil, RSSI: -30)

        try! database.handshakesStorage.add(handshake: h1)
        try! database.handshakesStorage.add(handshake: h2)
        try! database.generateContactsFromHandshakes()

        let bucketStart = ts.timeIntervalSince1970 - ts.timeIntervalSince1970.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)

        let c = try! database.contactsStorage.getContacts(for: day, overlappingTimeInverval: .day, contactThreshold: 1)
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c.first!.ephID, token)
        XCTAssertEqual(c.first!.date, Date(timeIntervalSince1970: bucketStart))
    }

    func testContactGenerationUniqueDifferentEpoch() {
        let ts = DP3TCryptoModule.getEpochStart().addingTimeInterval(-CryptoConstants.secondsPerEpoch)
        let day = DayDate(date: ts)


        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!
        let h1 = HandshakeModel(identifier: nil, timestamp: ts, ephID: token, TXPowerlevel: nil, RSSI: -30)
        let h11 = HandshakeModel(identifier: nil, timestamp: ts.addingTimeInterval(10), ephID: token, TXPowerlevel: nil, RSSI: -30)

        let yesterday = ts.addingTimeInterval(-.day)
        let token2 = Data(base64Encoded: "MSjnTLwp9z6XIJxGklwPPw==")!
        let h2 = HandshakeModel(identifier: nil, timestamp: yesterday, ephID: token2, TXPowerlevel: nil, RSSI: -30)
        let h21 = HandshakeModel(identifier: nil, timestamp: yesterday.addingTimeInterval(10), ephID: token2, TXPowerlevel: nil, RSSI: -30)

        try! database.handshakesStorage.add(handshake: h1)
        try! database.handshakesStorage.add(handshake: h11)
        try! database.handshakesStorage.add(handshake: h2)
        try! database.handshakesStorage.add(handshake: h21)
        try! database.generateContactsFromHandshakes()

        let c = try! database.contactsStorage.getContacts(for: day, overlappingTimeInverval: .day, contactThreshold: 1)
        XCTAssertEqual(c.count, 2)
    }

    func testContactGenerationThisEpoch() {
        let date = Date()
        let day = DayDate(date: date)

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!
        let h1 = HandshakeModel(identifier: nil, timestamp: Date(), ephID: token, TXPowerlevel: nil, RSSI: -30)

        try! database.handshakesStorage.add(handshake: h1)

        let h2 = HandshakeModel(identifier: nil, timestamp: Date().addingTimeInterval(5), ephID: token, TXPowerlevel: nil, RSSI: -30)
        try! database.handshakesStorage.add(handshake: h2)

        try! database.generateContactsFromHandshakes()

        let c = try! database.contactsStorage.getContacts(for: day)
        XCTAssertTrue(c.isEmpty)
    }

    func testDeleteOldContacts(){
        let date = DayDate().dayMin.addingTimeInterval(-(Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day + 1))

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!

        let contact = Contact(identifier: nil, ephID: token, date: date, windowCount: 0, associatedKnownCase: nil)
        database.contactsStorage.add(contact: contact)
        var count = try! database.contactsStorage.count()
        XCTAssertEqual(count, 1)
        try! database.contactsStorage.deleteOldContacts()
        count = try! database.contactsStorage.count()
        XCTAssertEqual(count, 0)
    }

    func testNotDeleteNewContacts() {
        let date = Date().addingTimeInterval(-(Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day * 0.5))

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!

        let contact = Contact(identifier: nil, ephID: token, date: date, windowCount: 0, associatedKnownCase: nil)
        database.contactsStorage.add(contact: contact)
        var count = try! database.contactsStorage.count()
        XCTAssertEqual(count, 1)
        try! database.contactsStorage.deleteOldContacts()
        count = try! database.contactsStorage.count()
        XCTAssertEqual(count, 1)
    }

    func testDeleteOldHandshakes(){
        let date = DayDate().dayMin.addingTimeInterval(-(Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day + 1))

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!

        let h1 = HandshakeModel(identifier: nil, timestamp: date, ephID: token, TXPowerlevel: nil, RSSI: -30)
        try! database.handshakesStorage.add(handshake: h1)
        var count = try! database.handshakesStorage.count()
        XCTAssertEqual(count, 1)
        try! database.handshakesStorage.deleteOldHandshakes()
        count = try! database.handshakesStorage.count()
        XCTAssertEqual(count, 0)
    }

    func testNotDeleteNewHandshakes() {
        let date = Date().addingTimeInterval(-(Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day * 0.5))

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!

        let h1 = HandshakeModel(identifier: nil, timestamp: date, ephID: token, TXPowerlevel: nil, RSSI: -30)
        try! database.handshakesStorage.add(handshake: h1)
        var count = try! database.handshakesStorage.count()
        XCTAssertEqual(count, 1)
        try! database.handshakesStorage.deleteOldHandshakes()
        count = try! database.handshakesStorage.count()
        XCTAssertEqual(count, 1)
    }

    func testDeleteBulkHandshakes(){
        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!
        let date = Date()

        let h1 = HandshakeModel(identifier: nil, timestamp: date, ephID: token, TXPowerlevel: nil, RSSI: -30)
        try! database.handshakesStorage.add(handshake: h1)
        let h2 = HandshakeModel(identifier: nil, timestamp: date, ephID: token, TXPowerlevel: nil, RSSI: -30)
        try! database.handshakesStorage.add(handshake: h2)
        let handshakes = try! database.handshakesStorage.getAll()
        XCTAssertEqual(handshakes.count, 2)

        try! database.handshakesStorage.delete(handshakes)

        XCTAssertEqual(try! database.handshakesStorage.count(), 0)
    }


    static var allTests = [
        ("testEmptyStorage", testEmptyStorage),
        ("testContactGeneration", testContactGeneration),
        ("testDeleteOldContacts", testDeleteOldContacts),
        ("testNotDeleteNewContacts", testNotDeleteNewContacts),
        ("testDeleteOldHandshakes", testDeleteOldHandshakes),
        ("testNotDeleteNewHandshakes", testNotDeleteNewHandshakes),
        ("testContactGenerationUnique", testContactGenerationUnique),
        ("testContactGenerationUniqueDifferentEpoch", testContactGenerationUniqueDifferentEpoch),
        ("testDeleteBulkHandshakes", testDeleteBulkHandshakes)
    ]
}
