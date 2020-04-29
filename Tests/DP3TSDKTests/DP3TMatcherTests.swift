/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import SQLite
import XCTest

private class MockMatcherDelegate: DP3TMatcherDelegate {
    var didFindMatchStorage: Bool = false

    func didFindMatch() {
        didFindMatchStorage = true
    }

    func handShakeAdded(_: HandshakeModel) {}
}

final class DP3TMatcherTests: XCTestCase {
    let connection = try! Connection(.inMemory, readonly: false)

    lazy var database: DP3TDatabase! = try! DP3TDatabase(connection_: connection)

    var store: KeyStoreMock!

    var crypto: DP3TCryptoModule!

    fileprivate var delegate: MockMatcherDelegate!

    var matcher: DP3TMatcher!

    var nowTs: TimeInterval!

    var currentBatchStart: TimeInterval!

    var currentBatchStartDate: Date!

    override func setUp() {
        nowTs = Date().timeIntervalSince1970

        currentBatchStart = nowTs - nowTs.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)

        currentBatchStartDate = Date(timeIntervalSince1970: currentBatchStart)

        store = KeyStoreMock()
        crypto = try! DP3TCryptoModule(store: store)
        delegate = MockMatcherDelegate()
        matcher = try! DP3TMatcher(database: database, crypto: crypto)
        matcher.delegate = delegate
    }

    override func tearDown() {
        try! database.emptyStorage()
    }

    func testFindMatchSingleEnaughtWindowsNotMatching() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskoc==")!

        let c = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: ContactFactory.numberOfWindowsForExposure + 1, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCase(knownCase)

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testFindMatchSingleEnaughtWindows() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let c = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: ContactFactory.numberOfWindowsForExposure + 1, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCase(knownCase)

        XCTAssert(delegate.didFindMatchStorage)

        let contacts = try! database.contactsStorage.getAllMatchedContacts()
        XCTAssertEqual(contacts.isEmpty, false)
        XCTAssertEqual(contacts.first!.date, currentBatchStartDate)
        XCTAssertEqual(contacts.first!.windowCount, ContactFactory.numberOfWindowsForExposure + 1)

        let days = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(days.isEmpty, false)
        XCTAssertEqual(days.first!.exposedDate, DayDate(date: currentBatchStartDate).dayMin)
    }

    func testFindMatchSingleNotEnaughtWindows() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let c = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: ContactFactory.numberOfWindowsForExposure, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCase(knownCase)

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testFindMatchMulipleContactsToReachThreshold() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let parts = Int(ceil(Double(ContactFactory.numberOfWindowsForExposure + 1) / 3.0))

        let c1 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c1)

        let c2 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c2)

        let c3 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c3)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCase(knownCase)

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testFindMatchMulipleContactsToReachThresholdMultipleDistance() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let parts = Int(ceil(Double(ContactFactory.numberOfWindowsForExposure + 1) / 3.0))

        let dayStart = DayDate(date: currentBatchStartDate).dayMin

        let c1 = Contact(identifier: nil, ephID: token, date: dayStart.addingTimeInterval(.hour * 1), windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c1)

        let c2 = Contact(identifier: nil, ephID: token, date: dayStart.addingTimeInterval(.hour * 5), windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c2)

        let c3 = Contact(identifier: nil, ephID: token, date: dayStart.addingTimeInterval(.hour * 6), windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c3)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCase(knownCase)

        XCTAssert(delegate.didFindMatchStorage)
    }

    func testFindMatchMulipleContactsNotToReachThreshold() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let parts = Int(ceil(Double(ContactFactory.numberOfWindowsForExposure + 1) / 3.0))

        let c1 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c1)

        let c2 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c2)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCase(knownCase)

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testNotCallingDelegateForOldMatch() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let c = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: ContactFactory.numberOfWindowsForExposure + 1, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCase(knownCase)

        XCTAssert(delegate.didFindMatchStorage)

        delegate.didFindMatchStorage = false

        try! matcher.checkNewKnownCase(knownCase)

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testWithMultipleDaysMatching() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let c = Contact(identifier: nil,
                        ephID: token,
                        date: currentBatchStartDate,
                        windowCount: ContactFactory.numberOfWindowsForExposure + 1,
                        associatedKnownCase: nil)

        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCase(knownCase)

        XCTAssert(delegate.didFindMatchStorage)

        delegate.didFindMatchStorage = false

        let c2 = Contact(identifier: nil,
                         ephID: token,
                         date: currentBatchStartDate.addingTimeInterval(-.day),
                         windowCount: ContactFactory.numberOfWindowsForExposure + 1,
                         associatedKnownCase: nil)
        database.contactsStorage.add(contact: c2)

        let knownCase1 = KnownCaseModel(id: nil,
                                        key: key,
                                        onset: Date().addingTimeInterval(-.day * 2),
                                        batchTimestamp: currentBatchStartDate.addingTimeInterval(-.day + NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase1])

        try! matcher.checkNewKnownCase(knownCase1)

        XCTAssert(delegate.didFindMatchStorage)

        let days = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(days.count, 2)
    }

    func testMatchingWithGivenSql(){
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!

        try! connection.execute("""
            INSERT INTO "contacts" ("id", "date", "ephID", "associated_known_case", "windowsCount") VALUES
            ('1', '1588159500000', X'1E8F776BD0EB845B5900262166FE1153', NULL, '2'),
            ('2', '1588158900000', X'75F02545B18FDD3E4E4693B2208A4915', '13', '5'),
            ('3', '1588159800000', X'C966F5F4929EC2D63BEF1069C76EC7F1', '13', '5'),
            ('4', '1588160700000', X'A8353DBEF149D988C014127241D5AC88', NULL, '7'),
            ('5', '1588161000000', X'C67FF2C99FE2036F81EB0779A5C44FCC', '13', '2'),
            ('6', '1588161600000', X'C52CC74AC52D51F47B13AC107899A92B', '13', '5'),
            ('7', '1588161600000', X'BAF3EEDF833B98BB5750F3F5EAB8D23B', NULL, '9');
            """
        )

        let knownCase1 = KnownCaseModel(id: nil,
                                        key: key,
                                        onset: Date().addingTimeInterval(-.day * 2),
                                        batchTimestamp: currentBatchStartDate.addingTimeInterval(-.day + NetworkingConstants.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase1])

        try! matcher.checkNewKnownCase(knownCase1)

        XCTAssert(delegate.didFindMatchStorage)
    }
}
