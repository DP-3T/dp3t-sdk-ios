/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

/// Storage used to persist exposed Contacts
class MatchedContactsStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("matched_contacts")

    /// Column definitions
    let idColumn = Expression<Int>("id")
    let reportDateColumn = Expression<Date>("report_date")
    let associatedKnownCaseIdColumn = Expression<Int>("known_case_id")

    /// Initializer
    /// - Parameters:
    ///   - database: database Connection
    ///   - knownCasesStorage: knownCases Storage
    init(database: Connection, knownCasesStorage: KnownCasesStorage) throws {
        self.database = database
        try createTable(knownCasesStorage: knownCasesStorage)
    }

    /// Create the table
    private func createTable(knownCasesStorage: KnownCasesStorage) throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(reportDateColumn)
            //TODO: PP-139: setnull? does it matter?
            t.foreignKey(associatedKnownCaseIdColumn, references: knownCasesStorage.table, knownCasesStorage.idColumn, delete: .setNull)
        })
    }

    /// count of entries
    func count() throws -> Int {
        try database.scalar(table.count)
    }

    /// add a matched contact
    /// - Parameter matchedContact: the known case that matched to a contact to add
    func add(matchedContact: MatchedContact) throws {
        let insert = table.insert(
            reportDateColumn <- matchedContact.reportDate,
            associatedKnownCaseIdColumn <- matchedContact.identifier
        )
        try database.run(insert)
    }

    /// Helper function to retrieve Contacts from Handshakes
    /// - Parameters:
    ///   - day: the day for which to retreive contact
    ///   - overlappingTimeInverval: timeinterval to add/subtract for contact retreival
    ///   - contactThreshold: how many handshakes to have to be recognized as contact
    /// - Throws: if a database error happens
    /// - Returns: list of contacts
    func getMatchedContacts() throws -> [MatchedContact] {
        try deleteExpiredMatchedContacts()

        var matchedContacts = [MatchedContact]()
        for row in try database.prepare(table) {
            let matchedContact = MatchedContact(identifier: row[associatedKnownCaseIdColumn],
                                                reportDate: row[reportDateColumn])
            matchedContacts.append(matchedContact)
        }

        return matchedContacts
    }

    /// Deletes contacts older than CryptoConstants.numberOfDaysToKeepData
    func deleteExpiredMatchedContacts() throws {
        let thresholdDate: Date = DayDate().dayMin.addingTimeInterval(-Double(CryptoConstants.numberOfDaysToKeepMatchedContacts) * TimeInterval.day)
        let deleteQuery = table.filter(reportDateColumn < thresholdDate)
        try database.run(deleteQuery.delete())
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }
}
