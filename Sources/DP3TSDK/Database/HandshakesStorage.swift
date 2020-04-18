/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

/// Storage used to persist DP3T handshakes
class HandshakesStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("handshakes")

    /// Column definitions
    let idColumn = Expression<Int>("id")
    let timestampColumn = Expression<Date>("timestamp")
    let ephIDColumn = Expression<EphID>("ephID")
    let TXPowerlevelColumn = Expression<Double?>("tx_power_level")
    let RSSIColumn = Expression<Double?>("rssi")

    /// Initializer
    /// - Parameters:
    ///   - database: database Connection
    ///   - knownCasesStorage: knownCases Storage
    init(database: Connection) throws {
        self.database = database
        try createTable()
    }

    /// Create the table
    private func createTable() throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(timestampColumn)
            t.column(ephIDColumn)
            t.column(TXPowerlevelColumn)
            t.column(RSSIColumn)
        })
    }

    /// count of entries
    func count() throws -> Int {
        try database.scalar(table.count)
    }

    /// add a Handshake
    /// - Parameter h: handshake
    func add(handshake h: HandshakeModel) throws {
        let insert = table.insert(
            timestampColumn <- h.timestamp,
            ephIDColumn <- h.ephID,
            TXPowerlevelColumn <- h.TXPowerlevel,
            RSSIColumn <- h.RSSI
        )
        try database.run(insert)
    }

    /// Deletes handshakes older than CryptoConstants.numberOfDaysToKeepData
    func deleteOldHandshakes() throws {
        let thresholdDate: Date = DayDate().dayMin.addingTimeInterval(-Double(CryptoConstants.numberOfDaysToKeepData) * TimeInterval.day)
        let deleteQuery = table.filter(timestampColumn < thresholdDate)
        try database.run(deleteQuery.delete())
    }

    /// Delete processed handshakes
    /// - Parameter handshakes: the handshakes to delete
    /// - Throws: if a error happens
    func delete(_ handshakes: [HandshakeModel]) throws {
        let identifiers = handshakes.compactMap(\.identifier)
        let deleteQuery = table.filter(identifiers.contains(idColumn))
        try database.run(deleteQuery.delete())
    }

    /// get all Handshakes newer than timestamp
    /// - Parameter olderThan: the timestamp to compare with
    /// - Throws: if a error happens
    /// - Returns: the handshakes
    func getAll(olderThan date: Date = Date()) throws -> [HandshakeModel] {
        var handshakes = [HandshakeModel]()
        for row in try database.prepare(table.filter(timestampColumn < date)) {
            let model = HandshakeModel(identifier: row[idColumn],
                                       timestamp: row[timestampColumn],
                                       ephID: row[ephIDColumn],
                                       TXPowerlevel: row[TXPowerlevelColumn],
                                       RSSI: row[RSSIColumn])
            handshakes.append(model)
        }
        return handshakes
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }

    func numberOfHandshakes() throws -> Int {
        try database.scalar(table.count)
    }
}

#if CALIBRATION

extension HandshakesStorage {

    func getHandshakes(_ request: HandshakeRequest) throws -> HandshakeResponse {
        var query = table

        // Limit
        if let limit = request.limit {
            assert(limit > 0, "Limits should be at least one")
            assert(request.offset >= 0, "Offset must be positive")
            query = query.limit(limit, offset: request.offset)
        }

        // Sorting
        switch request.sortingOption {
        case .ascendingTimestamp:
            query = query.order(timestampColumn.asc)
        case .descendingTimestamp:
            query = query.order(timestampColumn.desc)
        }

        var handshakes = [HandshakeModel]()
        for row in try database.prepare(query) {
            let model = HandshakeModel(timestamp: row[timestampColumn],
                                       ephID: row[ephIDColumn],
                                       TXPowerlevel: row[TXPowerlevelColumn],
                                       RSSI: row[RSSIColumn])
            handshakes.append(model)
        }

        let previousRequest: HandshakeRequest?
        if request.offset > 0, let limit = request.limit {
            let diff = request.offset - limit
            let previousOffset = max(0, diff)
            let previousLimit = limit + min(0, diff)
            previousRequest = HandshakeRequest(offset: previousOffset, limit: previousLimit)
        } else {
            previousRequest = nil
        }

        let nextRequest: HandshakeRequest?
        if request.limit == nil || handshakes.count < request.limit! {
            nextRequest = nil
        } else {
            let nextOffset = request.offset + request.limit!
            nextRequest = HandshakeRequest(offset: nextOffset, limit: request.limit)
        }

        return HandshakeResponse(handshakes: handshakes, offset: request.offset, limit: request.limit, previousRequest: previousRequest, nextRequest: nextRequest)
    }
}

public struct HandshakeRequest {
    public enum SortingOption {
        case ascendingTimestamp
        case descendingTimestamp
    }

    public let sortingOption: SortingOption
    public let offset: Int
    public let limit: Int?
    public init(sortingOption: SortingOption = .descendingTimestamp, offset: Int = 0, limit: Int? = nil) {
        self.sortingOption = sortingOption
        self.offset = offset
        self.limit = limit
    }
}

public struct HandshakeResponse {
    public let offset: Int
    public let limit: Int?
    public let handshakes: [HandshakeModel]
    public let previousRequest: HandshakeRequest?
    public let nextRequest: HandshakeRequest?
    fileprivate init(handshakes: [HandshakeModel], offset: Int, limit: Int?, previousRequest: HandshakeRequest?, nextRequest: HandshakeRequest?) {
        self.handshakes = handshakes
        self.previousRequest = previousRequest
        self.nextRequest = nextRequest
        self.offset = offset
        self.limit = limit
    }
}

#endif
