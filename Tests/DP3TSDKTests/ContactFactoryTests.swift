/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

@testable import DP3TSDK
import XCTest

final class ContactFactoryTests: XCTestCase {
    func testShouldGrouping() {
        let token = Data(base64Encoded: "30+i6bJjzmOWMa0uUPH9LA==")!
        let date = Date()
        let handshake1 = HandshakeModel(identifier: 0, timestamp: date, ephID: token, TXPowerlevel: nil, RSSI: nil)
        let handshake2 = HandshakeModel(identifier: 1, timestamp: date.addingTimeInterval(1), ephID: token, TXPowerlevel: nil, RSSI: nil)
        let handshakes = [handshake1, handshake2]
        let contacts = ContactFactory.contacts(from: handshakes, contactThreshold: 0)
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts.first?.day , DayDate(date: date))
        XCTAssertEqual(contacts.first?.ephID, token)
    }

    func testShouldNotGroup(){
        let token1 = Data(base64Encoded: "30+i6bJjzmOWMa0uUPH9LA==")!
        let token2 = Data(base64Encoded: "/B9V3P3dk6g73AuO2iEgzQ==")!
        let handshake1 = HandshakeModel(identifier: 0, timestamp: Date(), ephID: token1, TXPowerlevel: nil, RSSI: nil)
        let handshake2 = HandshakeModel(identifier: 1, timestamp: Date().addingTimeInterval(1), ephID: token2, TXPowerlevel: nil, RSSI: nil)
        let handshakes = [handshake1, handshake2]
        let contacts = ContactFactory.contacts(from: handshakes, contactThreshold: 0)
        XCTAssertEqual(contacts.count, 2)
    }

    func testShouldFilterOut(){
        let token = Data(base64Encoded: "30+i6bJjzmOWMa0uUPH9LA==")!
        let handshake1 = HandshakeModel(identifier: 0, timestamp: Date(), ephID: token, TXPowerlevel: nil, RSSI: nil)
        let handshakes = [handshake1]
        let contacts = ContactFactory.contacts(from: handshakes, contactThreshold: 1)
        XCTAssertTrue(contacts.isEmpty)
    }

    func testShouldNotFilterOut(){
        let token = Data(base64Encoded: "30+i6bJjzmOWMa0uUPH9LA==")!
        let handshake1 = HandshakeModel(identifier: 0, timestamp: Date(), ephID: token, TXPowerlevel: nil, RSSI: nil)
        let handshake2 = HandshakeModel(identifier: 1, timestamp: Date().addingTimeInterval(1), ephID: token, TXPowerlevel: nil, RSSI: nil)
        let handshakes = [handshake1, handshake2]
        let contacts = ContactFactory.contacts(from: handshakes, contactThreshold: 0)
        XCTAssertEqual(contacts.count, 1)
    }

    static var allTests = [
        ("testShouldGrouping", testShouldGrouping),
        ("testShouldNotGroup", testShouldNotGroup),
        ("testShouldFilterOut", testShouldFilterOut),
        ("testShouldNotFilterOut", testShouldNotFilterOut)
    ]
}
