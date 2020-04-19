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

/// matcher for DP3T tokens
class DP3TMatcher {
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
    func checkNewKnownCase(_ knownCase: KnownCaseModel, bucketDay: String) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = CryptoConstants.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let onset = dateFormatter.date(from: knownCase.onset)!
        let bucketDayDate = dateFormatter.date(from: bucketDay)!

        let contacts = try crypto.checkContacts(secretKey: knownCase.key,
                                                onsetDate: DayDate(date: onset),
                                                bucketDate: DayDate(date: bucketDayDate)) { (day) -> ([Contact]) in
            (try? database.contactsStorage.getContacts(for: day)) ?? []
        }

        if !contacts.isEmpty,
            let knownCaseId = try? database.knownCasesStorage.getId(for: knownCase.key) {
            try contacts.forEach { (contact) in
                guard let contactId = contact.identifier else { return }
                try database.contactsStorage.addKnownCase(knownCaseId, to: contactId)
            }

            delegate.didFindMatch()
        }
    }
}

// MARK: BluetoothDiscoveryDelegate implementation

extension DP3TMatcher: BluetoothDiscoveryDelegate {
    func didDiscover(data: EphID, TXPowerlevel: Double?, RSSI: Double?) throws {
        // Do no realtime matching
        let handshake = HandshakeModel(timestamp: Date(),
                                       ephID: data,
                                       TXPowerlevel: TXPowerlevel,
                                       RSSI: RSSI)
        try database.handshakesStorage.add(handshake: handshake)

        delegate.handShakeAdded(handshake)
    }
}
