/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

/// Wrapper to return Peripheral data
struct PeripheralWrapper {
    let uuid: String
    let discoverTime: Date
    let lastConnection: Date?
}

class PeripheralStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("peripheral_last_connection")

    /// Column definitions
    let peripheralUUID = Expression<String>("peripheral_uuid")
    let discoverTime = Expression<Date>("discover_time")
    let lastConnection = Expression<Date?>("last_connection")

    /// Initializer
    /// - Parameter database: database connection
    init(database: Connection) throws {
        self.database = database
        try createTable()
    }

    /// Create the table
    private func createTable() throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(peripheralUUID, primaryKey: true)
            t.column(lastConnection)
            t.column(discoverTime)
        })
    }

    /// inserts a discovery for a peripheral
    /// - Parameter uuid: peripheral identifier
    func setDiscovery(uuid: UUID) throws {
        let query = table.insert(or: .replace, peripheralUUID <- uuid.uuidString,
                                 discoverTime <- Date())
        try database.run(query)
    }

    /// sets the lastconnection time for a peripheral
    /// - Parameter uuid: peripheral identifier
    func setConnection(uuid: UUID) throws {
        let query = table.filter(peripheralUUID == uuid.uuidString)
        try database.run(query.update(lastConnection <- Date()))
    }

    /// gets the periphal by identifier
    /// - Parameter uuid: peripheral identifier
    func get(uuid: UUID) throws -> PeripheralWrapper? {
        let query = table.filter(peripheralUUID == uuid.uuidString)
        guard let row = try database.pluck(query) else { return nil }
        return PeripheralWrapper(uuid: row[peripheralUUID], discoverTime: row[discoverTime], lastConnection: row[lastConnection])
    }

    /// helper function to loop through all entries
    /// - Parameter block: execution block should return false to break looping
    func loopThrough(block: (PeripheralWrapper) -> Bool) throws {
        for row in try database.prepare(table) {
            let model = PeripheralWrapper(uuid: row[peripheralUUID], discoverTime: row[discoverTime], lastConnection: row[lastConnection])
            if !block(model) {
                break
            }
        }
    }

    /// discard periphal by identifier
    /// - Parameter uuid: peripheral identifier
    func discard(uuid: String) throws {
        let query = table.filter(peripheralUUID == uuid)
        try database.run(query.delete())
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }
}
