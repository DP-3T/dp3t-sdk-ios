/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

/// Wrapper class for all Databases
class DP3TDatabase {
    /// Database connection
    private let connection: Connection

    /// flag used to set Database as destroyed
    private(set) var isDestroyed = false

    #if CALIBRATION
        public weak var logger: LoggingDelegate?
    #endif

    /// application Storage
    private let _applicationStorage: ApplicationStorage
    var applicationStorage: ApplicationStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _applicationStorage
    }

    /// handshaked Storage
    private let _handshakesStorage: HandshakesStorage
    var handshakesStorage: HandshakesStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _handshakesStorage
    }

    /// contacts Storage
    private let _contactsStorage: ContactsStorage
    var contactsStorage: ContactsStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _contactsStorage
    }

    /// knowncase Storage
    private let _knownCasesStorage: KnownCasesStorage
    var knownCasesStorage: KnownCasesStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _knownCasesStorage
    }

    /// peripheral Storage
    private let _peripheralStorage: PeripheralStorage
    var peripheralStorage: PeripheralStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _peripheralStorage
    }

    #if CALIBRATION
        /// logging Storage
        private let _logggingStorage: LoggingStorage
        var loggingStorage: LoggingStorage {
            guard !isDestroyed else { fatalError("Database is destroyed") }
            return _logggingStorage
        }
    #endif

    /// Initializer
    init(connection_: Connection? = nil) throws {
        if let connection = connection_ {
            self.connection = connection
        } else {
            self.connection = try Connection(DP3TDatabase.getDatabasePath(), readonly: false)
        }
        _knownCasesStorage = try KnownCasesStorage(database: connection)
        _handshakesStorage = try HandshakesStorage(database: connection)
        _contactsStorage = try ContactsStorage(database: connection, knownCasesStorage: _knownCasesStorage)
        _peripheralStorage = try PeripheralStorage(database: connection)
        _applicationStorage = try ApplicationStorage(database: connection)
        #if CALIBRATION
            _logggingStorage = try LoggingStorage(database: connection)
        #endif
    }

    /// Generates contacts from handshakes and deletes handshakes
    /// Should be called ragulary to ensure completenes of contacts
    /// - Throws: if error happens
    func generateContactsFromHandshakes() throws {
        try handshakesStorage.deleteOldHandshakes()
        let epochStart = DP3TCryptoModule.getCurrentEpochStart()
        let handshakes = try handshakesStorage.getAll(olderThan: epochStart)
        let contacts = ContactFactory.contacts(from: handshakes)
        contacts.forEach(contactsStorage.add(contact:))
        #if !CALIBRATION
        try handshakesStorage.delete(handshakes)
        #endif
        try contactsStorage.deleteOldContacts()
    }

    /// Discard all data
    func emptyStorage() throws {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        try connection.transaction {
            try handshakesStorage.emptyStorage()
            try knownCasesStorage.emptyStorage()
            try peripheralStorage.emptyStorage()
            #if CALIBRATION
                try loggingStorage.emptyStorage()
            #endif
            try contactsStorage.emptyStorage()
        }
    }

    /// delete Database
    func destroyDatabase() throws {
        let path = DP3TDatabase.getDatabasePath()
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
        isDestroyed = true
    }

    /// get database path
    private static func getDatabasePath() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("DP3T_tracing_db").appendingPathExtension("sqlite").absoluteString
    }
}

extension DP3TDatabase: CustomDebugStringConvertible {
    var debugDescription: String {
        return "DB at path <\(DP3TDatabase.getDatabasePath())>"
    }
}
