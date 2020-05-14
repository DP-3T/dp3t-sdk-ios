/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
#if CALIBRATION
import SQLite

/// Wrapper class for all Databases
class DP3TDatabase {
    /// Database connection
    private let connection: Connection

    /// flag used to set Database as destroyed
    private(set) var isDestroyed = false

    private let log = Logger(DP3TDatabase.self, category: "database")


    /// logging Storage
    private let _logggingStorage: LoggingStorage
    var loggingStorage: LoggingStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _logggingStorage
    }

    /// Initializer
    init(connection_: Connection? = nil) throws {
        if let connection = connection_ {
            self.connection = connection
        } else {
            var filePath = DP3TDatabase.getDatabasePath()
            connection = try Connection(filePath.absoluteString, readonly: false)
            try? filePath.addExcludedFromBackupAttribute()
        }


        _logggingStorage = try LoggingStorage(database: connection)
    }

    /// Discard all data
    func emptyStorage() throws {
        log.trace()
        guard !isDestroyed else { fatalError("Database is destroyed") }
        try connection.transaction {
            try loggingStorage.emptyStorage()
        }
    }

    /// delete Database
    func destroyDatabase() throws {
        let path = DP3TDatabase.getDatabasePath().absoluteString
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
        isDestroyed = true
    }

    /// get database path
    private static func getDatabasePath() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("DP3T_tracing_db").appendingPathExtension("sqlite")
    }
}

extension DP3TDatabase: CustomDebugStringConvertible {
    var debugDescription: String {
        return "DB at path <\(DP3TDatabase.getDatabasePath().absoluteString)>"
    }
}

#endif
