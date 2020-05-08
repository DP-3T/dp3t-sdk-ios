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

        // we can return here if we didn't find any new matching contacts
        guard matchingContacts.isEmpty == false else {
            return
        }

        guard let knownCaseId = try? database.knownCasesStorage.getId(for: knownCase.key) else {
            fatalError("Known case has to be in database at this point")
        }

        /// Store all matching links in database
        try matchingContacts.forEach { contact in
            guard let contactId = contact.identifier else { return }
            try database.contactsStorage.addKnownCase(knownCaseId, to: contactId)
        }

        /// Retreive all contacts which have a corresponsing knownCase
        let contacts = try database.contactsStorage.getAllMatchedContacts()

        /// Group contacts by date and associated windowCounts
        let groups = contacts.reduce(into: [DayDate: Int]()) { groups, current in
            let day = DayDate(date: current.date)
            let existing = groups[day] ?? 0
            groups[day] = existing + current.windowCount
        }

        let matchedDays = groups.compactMap { (day, windowCount) -> ExposureDay? in
            guard windowCount >= Default.shared.parameters.contactMatching.numberOfWindowsForExposure else { return nil }
            return ExposureDay(identifier: 0,
                               exposedDate: day.dayMin,
                               reportDate: Date())
        }

        let daysBefore = try database.exposureDaysStorage.getExposureDays()

        /// Save the matchedDays
        try matchedDays.forEach(database.exposureDaysStorage.add(_:))

        let daysAfter = try database.exposureDaysStorage.getExposureDays()

        /// Inform the delegate if we found a new match
        if daysBefore != daysAfter {
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
