/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

/// Storage used to persist application from the DP3T discovery
class ApplicationStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("applications")

    /// Column definitions
    let appIdColumn = Expression<String>("app_id")
    let descriptionColumn = Expression<String>("description")
    let backendBaseUrlColumn = Expression<URL>("backend_base_url")
    let contactColumn = Expression<String>("contact")

    /// Initializer
    /// - Parameter database: database connection
    init(database: Connection) throws {
        self.database = database
        try createTable()
    }

    /// Create the table
    private func createTable() throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(appIdColumn, primaryKey: true)
            t.column(descriptionColumn)
            t.column(backendBaseUrlColumn)
            t.column(contactColumn)
        })
    }

    /// Add a application descriptro
    /// - Parameter ad: The descriptor to add
    func add(appDescriptor ad: TracingApplicationDescriptor) throws {
        let insert = table.insert(or: .replace,
                                  appIdColumn <- ad.appId,
                                  descriptionColumn <- ad.description,
                                  backendBaseUrlColumn <- ad.backendBaseUrl,
                                  contactColumn <- ad.contact)
        try database.run(insert)
    }

    /// Retreive the descriptor for a specific application
    /// - Parameter appid: the application to look for
    func descriptor(for appid: String) throws -> TracingApplicationDescriptor? {
        let query = table.filter(appIdColumn == appid)
        guard let row = try database.pluck(query) else { return nil }
        return TracingApplicationDescriptor(appId: row[appIdColumn],
                                            description: row[descriptionColumn],
                                            backendBaseUrl: row[backendBaseUrlColumn],
                                            contact: row[contactColumn])
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }
}
