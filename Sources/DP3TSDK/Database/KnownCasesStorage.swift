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
    let dayColumn = Expression<String>("day")
    let onsetColumn = Expression<String>("onset")
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
            t.column(dayColumn)
            t.column(onsetColumn)
            t.column(keyColumn)
        })
    }

    /// update the list of known cases
    /// - Parameter kcs: known cases
    /// - Parameter day: day identifier
    func update(knownCases kcs: [KnownCaseModel], day: String) throws {
        // Remove old values
        let casesToRemove = table.filter(dayColumn == day)
        try database.run(casesToRemove.delete())

        try database.transaction {
            try kcs.forEach { try add(knownCase: $0, day: day) }
        }
    }

    func getId(for key: Data) throws -> Int? {
        let query = table.filter(keyColumn == key)
        guard let row = try database.pluck(query) else { return nil }
        return row[idColumn]
    }

    /// add a known case
    /// - Parameter kc: known case
    /// - Parameter day: day identifier
    private func add(knownCase kc: KnownCaseModel, day: String) throws {
        let insert = table.insert(
            dayColumn <- day,
            onsetColumn <- kc.onset,
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
            let model = KnownCaseModel(id: row[idColumn], key: row[keyColumn], onset: row[onsetColumn])
            if !block(model) {
                break
            }
        }
    }
}
