/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import SQLite
import XCTest

private class MockMatcherDelegate: MatcherDelegate {
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

    var matcher: Matcher!

    var nowTs: TimeInterval!

    var currentBatchStart: TimeInterval!

    var currentBatchStartDate: Date!

    override func setUp() {
        nowTs = Date().timeIntervalSince1970

        currentBatchStart = nowTs - nowTs.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength)

        currentBatchStartDate = Date(timeIntervalSince1970: currentBatchStart)

        store = KeyStoreMock()
        crypto = try! DP3TCryptoModule(store: store)
        delegate = MockMatcherDelegate()
        matcher = try! CustomImplementationMatcher(database: database, crypto: crypto)
        matcher.delegate = delegate
    }

    override func tearDown() {
        try! database.emptyStorage()
    }

    func testFindMatchSingleEnaughtWindowsNotMatching() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskoc==")!

        let c = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: Default.shared.parameters.contactMatching.numberOfWindowsForExposure + 1, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(Default.shared.parameters.networking.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCases([knownCase])

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testFindMatchSingleEnaughtWindows() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let c = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: Default.shared.parameters.contactMatching.numberOfWindowsForExposure + 1, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(Default.shared.parameters.networking.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCases([knownCase])

        XCTAssert(delegate.didFindMatchStorage)

        let contacts = try! database.contactsStorage.getAllMatchedContacts()
        XCTAssertEqual(contacts.isEmpty, false)
        XCTAssertEqual(contacts.first!.date, currentBatchStartDate)
        XCTAssertEqual(contacts.first!.windowCount, Default.shared.parameters.contactMatching.numberOfWindowsForExposure + 1)

        let days = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(days.isEmpty, false)
        XCTAssertEqual(days.first!.exposedDate, DayDate(date: currentBatchStartDate).dayMin)
    }

    func testFindMatchSingleNotEnaughtWindows() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let c = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: Default.shared.parameters.contactMatching.numberOfWindowsForExposure, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(Default.shared.parameters.networking.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCases([knownCase])

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testFindMatchMulipleContactsToReachThreshold() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let parts = Int(ceil(Double(Default.shared.parameters.contactMatching.numberOfWindowsForExposure + 1) / 3.0))

        let c1 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c1)

        let c2 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c2)

        let c3 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c3)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(Default.shared.parameters.networking.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCases([knownCase])

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testFindMatchMulipleContactsToReachThresholdMultipleDistance() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let parts = Int(ceil(Double(Default.shared.parameters.contactMatching.numberOfWindowsForExposure + 1) / 3.0))

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
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(Default.shared.parameters.networking.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCases([knownCase])

        XCTAssert(delegate.didFindMatchStorage)
    }

    func testFindMatchMulipleContactsNotToReachThreshold() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let parts = Int(ceil(Double(Default.shared.parameters.contactMatching.numberOfWindowsForExposure + 1) / 3.0))

        let c1 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c1)

        let c2 = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: parts, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c2)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(Default.shared.parameters.networking.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCases([knownCase])

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testNotCallingDelegateForOldMatch() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let c = Contact(identifier: nil, ephID: token, date: currentBatchStartDate, windowCount: Default.shared.parameters.contactMatching.numberOfWindowsForExposure + 1, associatedKnownCase: nil)
        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(Default.shared.parameters.networking.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCases([knownCase])

        XCTAssert(delegate.didFindMatchStorage)

        delegate.didFindMatchStorage = false

        try! matcher.checkNewKnownCases([knownCase])

        XCTAssert(!delegate.didFindMatchStorage)
    }

    func testWithMultipleDaysMatching() {
        let key = Data(base64Encoded: "n5N07F0UnZ3DLWCpZ6rmQbWVYS1TDF/ttHLT8SdaHRs=")!
        let token = Data(base64Encoded: "ZN5cLwKOJVAWC7caIHskog==")!

        let c = Contact(identifier: nil,
                        ephID: token,
                        date: currentBatchStartDate,
                        windowCount: Default.shared.parameters.contactMatching.numberOfWindowsForExposure + 1,
                        associatedKnownCase: nil)

        database.contactsStorage.add(contact: c)

        let knownCase = KnownCaseModel(id: nil,
                                       key: key,
                                       onset: Date().addingTimeInterval(-.day),
                                       batchTimestamp: currentBatchStartDate.addingTimeInterval(Default.shared.parameters.networking.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase])

        try! matcher.checkNewKnownCases([knownCase])

        XCTAssert(delegate.didFindMatchStorage)

        delegate.didFindMatchStorage = false

        let c2 = Contact(identifier: nil,
                         ephID: token,
                         date: currentBatchStartDate.addingTimeInterval(-.day),
                         windowCount: Default.shared.parameters.contactMatching.numberOfWindowsForExposure + 1,
                         associatedKnownCase: nil)
        database.contactsStorage.add(contact: c2)

        let knownCase1 = KnownCaseModel(id: nil,
                                        key: key,
                                        onset: Date().addingTimeInterval(-.day * 2),
                                        batchTimestamp: currentBatchStartDate.addingTimeInterval(-.day + Default.shared.parameters.networking.batchLength))
        try! database.knownCasesStorage.update(knownCases: [knownCase1])

        try! matcher.checkNewKnownCases([knownCase1])

        XCTAssert(delegate.didFindMatchStorage)

        let days = try! database.exposureDaysStorage.getExposureDays()
        XCTAssertEqual(days.count, 2)
    }

}
