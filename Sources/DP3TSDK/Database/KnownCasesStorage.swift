/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

/// Storage used to persist DP3T known cases
class KnownCasesStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("known_cases")

    /// Column definitions
    let idColumn = Expression<Int>("id")
    let batchTimestampColumn = Expression<Int64>("batchTimestamp")
    let onsetColumn = Expression<Int64>("onset")
    let keyColumn = Expression<Data>("key")

    /// Initializer
    /// - Parameter database: database connection
    init(database: Connection) throws {
        self.database = database
        try createTable()
    }

    /// Create the table
    private func createTable() throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(batchTimestampColumn)
            t.column(onsetColumn)
            t.column(keyColumn)
        })
    }

    /// update the list of known cases
    /// - Parameter kcs: known cases
    func update(knownCases kcs: [KnownCaseModel]) throws {
        try database.transaction {
            try kcs.forEach { try add(knownCase: $0) }
        }
    }

    func getId(for key: Data) throws -> Int? {
        let query = table.filter(keyColumn == key)
        guard let row = try database.pluck(query) else { return nil }
        return row[idColumn]
    }

    /// Deletes knownCases older than CryptoConstants.numberOfDaysToKeepData
       func deleteOldKnownCases() throws {
           let thresholdDate: Date = DayDate().dayMin.addingTimeInterval(-Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day)
           let deleteQuery = table.filter(batchTimestampColumn < thresholdDate.millisecondsSince1970)
           try database.run(deleteQuery.delete())
       }


    /// add a known case
    /// - Parameter kc: known case
    private func add(knownCase kc: KnownCaseModel) throws {
        let insert = table.insert(
            batchTimestampColumn <- kc.batchTimestamp.millisecondsSince1970,
            onsetColumn <- kc.onset.millisecondsSince1970,
            keyColumn <- kc.key
        )

        try database.run(insert)
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }

    /// helper function to loop through all entries
    /// - Parameter block: execution block should return false to break looping
    func loopThrough(block: (KnownCaseModel) -> Bool) throws {
        for row in try database.prepare(table) {
            let model = KnownCaseModel(id: row[idColumn],
                                       key: row[keyColumn],
                                       onset: Date(milliseconds: row[onsetColumn]),
                                       batchTimestamp: Date(milliseconds: row[batchTimestampColumn]))
            if !block(model) {
                break
            }
        }
    }
}
