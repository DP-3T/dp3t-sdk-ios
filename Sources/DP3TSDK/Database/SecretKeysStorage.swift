/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

#if CALIBRATION

import Foundation
import SQLite

/// Storage used to persist DP3T known cases
class SecretKeysStorage: SecretKeysStorageDelegate {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("calibration_secret_keys")

    /// Column definitions
    let keyColumn = Expression<Data>("key")
    let dateColumn = Expression<Date>("date")

    /// Initializer
    /// - Parameter database: database connection
    init(database: Connection) throws {
        self.database = database
        try createTable()
    }

    /// Create the table
    private func createTable() throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(keyColumn)
            t.column(dateColumn)
        })
    }

    /// update the list of secret keys
    func update(secretKeys: [SecretKey]) throws {
        try emptyStorage()
        try database.transaction {
            try secretKeys.forEach { try add(secretKey: $0) }
        }
    }

    /// add a secret key
    private func add(secretKey: SecretKey) throws {
        let insert = table.insert(
            keyColumn <- secretKey.keyData,
            dateColumn <- secretKey.day.dayMin
        )

        try database.run(insert)
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }
}


/// A secret keys storage delegate
protocol SecretKeysStorageDelegate: class {
    /// updates all secret keys in sql for debugging purposes only
    func update(secretKeys: [SecretKey]) throws
}

#endif
