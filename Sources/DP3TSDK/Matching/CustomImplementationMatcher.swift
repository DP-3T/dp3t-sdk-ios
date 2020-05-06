/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// matcher for DP3T tokens
class CustomImplementationMatcher: Matcher {
    /// The DP3T crypto algorithm
    private let crypto: DP3TCryptoModule

    /// Databse
    private weak var database: DP3TDatabase!

    /// Delegate to notify on DP3T events
    weak var delegate: MatcherDelegate?

    /// Initializer
    /// - Parameters:
    ///   - database: databse
    ///   - crypto: star algorithm
    init(database: DP3TDatabase, crypto: DP3TCryptoModule) throws {
        self.database = database
        self.crypto = crypto
    }

    func checkNewKnownCases(_ knownCases: [KnownCaseModel]) throws {
        try knownCases.forEach(checkNewKnownCase(_:))
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
            guard windowCount > Default.shared.parameters.contactMatching.numberOfWindowsForExposure else { return nil }
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
            delegate?.didFindMatch()
        }
    }
}
