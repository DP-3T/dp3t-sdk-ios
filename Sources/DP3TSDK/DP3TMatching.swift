/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// A delegate used to respond on DP3T events
protocol DP3TMatcherDelegate: class {
    /// We found a match
    func didFindMatch()

    /// A new handshake occured
    func handShakeAdded(_ handshake: HandshakeModel)
}

protocol DP3TMatcherProtocol: class {
    /// check for new known case
    /// - Parameter knownCase: known Case
    func checkNewKnownCase(_ knownCase: KnownCaseModel) throws
}

/// matcher for DP3T tokens
class DP3TMatcher: DP3TMatcherProtocol {
    /// The DP3T crypto algorithm
    private let crypto: DP3TCryptoModule

    /// Databse
    private weak var database: DP3TDatabase!

    /// Delegate to notify on DP3T events
    public weak var delegate: DP3TMatcherDelegate!

    /// Initializer
    /// - Parameters:
    ///   - database: databse
    ///   - crypto: star algorithm
    init(database: DP3TDatabase, crypto: DP3TCryptoModule) throws {
        self.database = database
        self.crypto = crypto
    }

    /// check for new known case
    /// - Parameter knownCase: known Case
    func checkNewKnownCase(_ knownCase: KnownCaseModel) throws {
        let matchingContacts = try crypto.checkContacts(secretKey: knownCase.key,
                                                onsetDate: DayDate(date: knownCase.onset),
                                                bucketDate: knownCase.batchTimestamp) { (day) -> ([Contact]) in
            (try? database.contactsStorage.getContacts(for: day)) ?? []
        }

        if !matchingContacts.isEmpty,
            let knownCaseId = try? database.knownCasesStorage.getId(for: knownCase.key) {

            try matchingContacts.forEach { (contact) in
                guard let contactId = contact.identifier else { return }
                try database.contactsStorage.addKnownCase(knownCaseId, to: contactId)
            }

            let matchedContact = MatchedContact(identifier: knownCaseId, reportDate: DayDate(date: knownCase.batchTimestamp).dayMin)
            try database.matchedContactsStorage.add(matchedContact: matchedContact)
            delegate.didFindMatch()
        }
    }
}

// MARK: BluetoothDiscoveryDelegate implementation

extension DP3TMatcher: BluetoothDiscoveryDelegate {
    func didDiscover(data: EphID, TXPowerlevel: Double?, RSSI: Double, timestamp: Date) throws {
        // Do no realtime matching
        let handshake = HandshakeModel(timestamp: timestamp,
                                       ephID: data,
                                       TXPowerlevel: TXPowerlevel,
                                       RSSI: RSSI)
        try database.handshakesStorage.add(handshake: handshake)

        delegate.handShakeAdded(handshake)
    }
}
