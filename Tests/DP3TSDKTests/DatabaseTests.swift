/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest
import SQLite

final class DatabaseTests: XCTestCase {

    let database = try! DP3TDatabase(connection_: try! Connection(.inMemory, readonly: false))


    override func tearDown() {
        try! database.emptyStorage()
    }

    func testEmptyStorage(){
        let date = Date()
        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!
        let h1 = HandshakeModel(identifier: nil, timestamp: date, ephID: token, TXPowerlevel: nil, RSSI: nil)
        try! database.handshakesStorage.add(handshake: h1)

        try! database.emptyStorage()

        let h = try! database.handshakesStorage.getAll()
        XCTAssertTrue(h.isEmpty)
    }

    func testContactGeneration() {
        let date = Date()
        let day = DayDate(date: date)

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!
        let h1 = HandshakeModel(identifier: nil, timestamp: Date().addingTimeInterval(-CryptoConstants.secondsPerEpoch), ephID: token, TXPowerlevel: nil, RSSI: nil)

        try! database.handshakesStorage.add(handshake: h1)

        let h2 = HandshakeModel(identifier: nil, timestamp: Date().addingTimeInterval(-( CryptoConstants.secondsPerEpoch + 5)), ephID: token, TXPowerlevel: nil, RSSI: nil)
        try! database.handshakesStorage.add(handshake: h2)

        try! database.generateContactsFromHandshakes()

        let c = try! database.contactsStorage.getContacts(for: day)
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c.first!.ephID, token)
        XCTAssertEqual(c.first!.day, day)
    }

    func testContactGenerationThisEpoch() {
        let date = Date()
        let day = DayDate(date: date)

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!
        let h1 = HandshakeModel(identifier: nil, timestamp: Date(), ephID: token, TXPowerlevel: nil, RSSI: nil)

        try! database.handshakesStorage.add(handshake: h1)

        let h2 = HandshakeModel(identifier: nil, timestamp: Date().addingTimeInterval(5), ephID: token, TXPowerlevel: nil, RSSI: nil)
        try! database.handshakesStorage.add(handshake: h2)

        try! database.generateContactsFromHandshakes()

        let c = try! database.contactsStorage.getContacts(for: day)
        XCTAssertTrue(c.isEmpty)
    }

    func testDeleteOldContacts(){
        let date = Date().addingTimeInterval(-(Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day + 1))
        let day = DayDate(date: date)

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!

        let contact = Contact(identifier: nil, ephID: token, day: day, associatedKnownCase: nil)
        try! database.contactsStorage.add(contact: contact)
        var count = try! database.contactsStorage.count()
        XCTAssertEqual(count, 1)
        try! database.contactsStorage.deleteOldContacts()
        count = try! database.contactsStorage.count()
        XCTAssertEqual(count, 0)
    }

    func testNotDeleteNewContacts() {
        let date = Date().addingTimeInterval(-(Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day * 0.5))
        let day = DayDate(date: date)

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!

        let contact = Contact(identifier: nil, ephID: token, day: day, associatedKnownCase: nil)
        try! database.contactsStorage.add(contact: contact)
        var count = try! database.contactsStorage.count()
        XCTAssertEqual(count, 1)
        try! database.contactsStorage.deleteOldContacts()
        count = try! database.contactsStorage.count()
        XCTAssertEqual(count, 1)
    }

    func testDeleteOldHandshakes(){
        let date = Date().addingTimeInterval(-(Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day + 1))

        let token = Data(base64Encoded: "MSjnTLwp9z6qIJxGklwPPw==")!

        let h1 = HandshakeModel(identifier: nil, timestamp: date, ephID: token, TXPowerlevel: nil, RSSI: nil)
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

        let h1 = HandshakeModel(identifier: nil, timestamp: date, ephID: token, TXPowerlevel: nil, RSSI: nil)
        try! database.handshakesStorage.add(handshake: h1)
        var count = try! database.handshakesStorage.count()
        XCTAssertEqual(count, 1)
        try! database.handshakesStorage.deleteOldHandshakes()
        count = try! database.handshakesStorage.count()
        XCTAssertEqual(count, 1)
    }


    static var allTests = [
        ("testEmptyStorage", testEmptyStorage),
        ("testContactGeneration", testContactGeneration),
        ("testDeleteOldContacts", testDeleteOldContacts),
        ("testNotDeleteNewContacts", testNotDeleteNewContacts),
        ("testDeleteOldHandshakes", testDeleteOldHandshakes),
        ("testNotDeleteNewHandshakes", testNotDeleteNewHandshakes)
    ]
}
