/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

/// Storage used to persist Contacts
class ContactsStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("contacts")

    /// Column definitions
    let idColumn = Expression<Int>("id")
    let dateColumn = Expression<Int64>("date")
    let ephIDColumn = Expression<EphID>("ephID")
    let windowCountColumn = Expression<Int>("windowsCount")
    let associatedKnownCaseColumn = Expression<Int?>("associated_known_case")

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
            t.column(dateColumn)
            t.column(ephIDColumn)
            t.column(associatedKnownCaseColumn)
            t.column(windowCountColumn)
            t.foreignKey(associatedKnownCaseColumn, references: knownCasesStorage.table, knownCasesStorage.idColumn, delete: .setNull)
            t.unique(dateColumn,ephIDColumn)
        })
    }

    /// count of entries
    func count() throws -> Int {
        try database.scalar(table.count)
    }

    /// add a Contact
    /// - Parameter contact: the Contact to add
    func add(contact: Contact) {
        let insert = table.insert(
            dateColumn <- Date(timeIntervalSince1970: contact.day.timestamp).millisecondsSince1970,
            ephIDColumn <- contact.ephID,
            windowCountColumn <- contact.windowCount,
            associatedKnownCaseColumn <- contact.associatedKnownCase
        )
        // can fail if contact already exists
        _ = try? database.run(insert)
    }

    /// Deletes contacts older than CryptoConstants.numberOfDaysToKeepData
    func deleteOldContacts() throws {
        let thresholdDate: Date = DayDate().dayMin.addingTimeInterval(-Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day)
        let deleteQuery = table.filter(dateColumn < thresholdDate.millisecondsSince1970)
        try database.run(deleteQuery.delete())
    }

    /// Add a known case to the contact
    /// - Parameters:
    ///   - knownCaseId: identifier of known case
    ///   - contacttId: identifier of contact
    func addKnownCase(_ knownCaseId: Int, to contactId: Int) throws {
        let contactRow = table.filter(idColumn == contactId)
        try database.run(contactRow.update(associatedKnownCaseColumn <- knownCaseId))
    }

    /// Helper function to retrieve Contacts from Handshakes
    /// - Parameters:
    ///   - day: the day for which to retreive contact
    ///   - overlappingTimeInverval: timeinterval to add/subtract for contact retreival
    ///   - contactThreshold: how many handshakes to have to be recognized as contact
    /// - Throws: if a database error happens
    /// - Returns: list of contacts
    func getContacts(for day: DayDate, overlappingTimeInverval: TimeInterval = 0, contactThreshold: Int = 1) throws -> [Contact] {

        // if the day is older than .numberOfDaysToKeepData we can skip fetching contacts from the databae
        // since we dont keep them so long anyway
        if day.dayMin.timeIntervalSinceNow > TimeInterval(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day {
            return []
        }

        // extend dayMin and dayMax by given overlappintTimeInterval
        let dayMin = day.dayMin.addingTimeInterval(-overlappingTimeInverval).millisecondsSince1970
        let dayMax = day.dayMax.addingTimeInterval(overlappingTimeInverval).millisecondsSince1970

        let query = table.filter(dayMin...dayMax ~= dateColumn)

        var contacts = [Contact]()
        for row in try database.prepare(query) {
            guard row[associatedKnownCaseColumn] == nil else { continue }
            let model = Contact(identifier: row[idColumn],
                                ephID: row[ephIDColumn],
                                day: DayDate(date: Date(milliseconds: row[dateColumn])),
                                windowCount: row[windowCountColumn],
                                associatedKnownCase: row[associatedKnownCaseColumn])
            contacts.append(model)
        }

        return contacts
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }
}
