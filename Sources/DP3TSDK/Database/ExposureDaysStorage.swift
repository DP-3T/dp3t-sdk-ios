/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

/// Storage used to persist exposed days
class ExposureDaysStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("exposure_days")

    /// Column definitions
    let idColumn = Expression<Int>("id")
    let reportDateColumn = Expression<Int64>("report_date")
    let exposedDateColumn = Expression<Int64>("exposed_date")
    let isDeletedColumn = Expression<Bool>("is_deleted")

    /// Initializer
    /// - Parameters:
    ///   - database: database Connection
    init(database: Connection) throws {
        self.database = database
        try createTable()
    }

    /// Create the table
    private func createTable() throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(reportDateColumn)
            t.column(exposedDateColumn)
            t.column(isDeletedColumn)
            t.unique([exposedDateColumn])
        })
    }

    /// count of entries
    func count() throws -> Int {
        try database.scalar(table.count)
    }

    /// add a matched contact
    /// - Parameter matchedContact: the known case that matched to a contact to add
    func add(_ exposureDate: ExposureDay) throws {
        let insert = table.insert(or: .ignore,
                                  exposedDateColumn <- exposureDate.exposedDate.millisecondsSince1970,
                                  reportDateColumn <- exposureDate.reportDate.millisecondsSince1970,
                                  isDeletedColumn <- exposureDate.isDeleted)
        try database.run(insert)
    }

    /// Helper function to retrieve Exposuredays
    /// - Throws: if a database error happens
    /// - Returns: list of exposure days
    func getExposureDays() throws -> [ExposureDay] {
        try deleteExpiredExpsureDays()
        let query = table.filter(isDeletedColumn == false).order(reportDateColumn.asc)

        var exposureDays = [ExposureDay]()
        for row in try database.prepare(query) {
            let exposureDay = ExposureDay(identifier: row[idColumn],
                                          exposedDate: Date(milliseconds: row[exposedDateColumn]),
                                          reportDate: Date(milliseconds: row[reportDateColumn]),
                                          isDeleted: row[isDeletedColumn])
            exposureDays.append(exposureDay)
        }

        return exposureDays
    }

    /// Deletes contacts older than CryptoConstants.numberOfDaysToKeepData
    func deleteExpiredExpsureDays() throws {
        let thresholdDate: Date = DayDate().dayMin.addingTimeInterval(-Double(Default.shared.parameters.crypto.numberOfDaysToKeepMatchedContacts) * TimeInterval.day)
        let deleteQuery = table.filter(reportDateColumn < thresholdDate.millisecondsSince1970)
        try database.run(deleteQuery.delete())
    }

    func markExposuresAsDeleted() throws {
        let query = table.update(isDeletedColumn <- true)
        try database.run(query)
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }
}
