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
    let ephIDColumn = Expression<Data>("ephID")
    let TXPowerlevelColumn = Expression<Double?>("tx_power_level")
    let RSSIColumn = Expression<Double?>("rssi")
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
            t.column(timestampColumn)
            t.column(ephIDColumn)
            t.column(associatedKnownCaseColumn)
            t.column(TXPowerlevelColumn)
            t.column(RSSIColumn)
            t.foreignKey(associatedKnownCaseColumn, references: knownCasesStorage.table, knownCasesStorage.idColumn, delete: .setNull)
        })
    }

    /// returns the known Case Id for a token
    func ephIDExists(ephID: Data) throws -> Int? {
        let query = table.filter(ephIDColumn == ephID)
        let row = try database.pluck(query)
        return row?[associatedKnownCaseColumn]
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
            associatedKnownCaseColumn <- h.knownCaseId,
            TXPowerlevelColumn <- h.TXPowerlevel,
            RSSIColumn <- h.RSSI
        )
        try database.run(insert)
    }

    /// Add a known case to the handshake
    /// - Parameters:
    ///   - knownCaseId: identifier of known case
    ///   - handshakeId: identifier of handshake
    func addKnownCase(_ knownCaseId: Int, to handshakeId: Int) throws {
        let handshakeRow = table.filter(idColumn == handshakeId)
        try database.run(handshakeRow.update(associatedKnownCaseColumn <- knownCaseId))
    }

    /// helper function to loop through all entries
    func getBy(day: Date) throws -> [HandshakeModel] {
        let query = table.filter(timestampColumn >= day.dayMin && timestampColumn <= day.dayMax)
        var models = [HandshakeModel]()
        for row in try database.prepare(query) {
            guard row[associatedKnownCaseColumn] == nil else { continue }
            var model = HandshakeModel(timestamp: row[timestampColumn],
                                       ephID: row[ephIDColumn],
                                       TXPowerlevel: row[TXPowerlevelColumn],
                                       RSSI: row[RSSIColumn],
                                       knownCaseId: nil)
            model.identifier = row[idColumn]
            models.append(model)
        }
        return models
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }

    func numberOfHandshakes() throws -> Int {
        try database.scalar(table.count)
    }

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

        // Filtering
        if request.filterOption.contains(.hasKnownCaseAssociated) {
            query = query.filter(associatedKnownCaseColumn != nil)
        }

        var handshakes = [HandshakeModel]()
        for row in try database.prepare(query) {
            let model = HandshakeModel(timestamp: row[timestampColumn],
                                       ephID: row[ephIDColumn],
                                       TXPowerlevel: row[TXPowerlevelColumn],
                                       RSSI: row[RSSIColumn],
                                       knownCaseId: row[associatedKnownCaseColumn])
            handshakes.append(model)
        }

        let previousRequest: HandshakeRequest?
        if request.offset > 0, let limit = request.limit {
            let diff = request.offset - limit
            let previousOffset = max(0, diff)
            let previousLimit = limit + min(0, diff)
            previousRequest = HandshakeRequest(filterOption: request.filterOption, offset: previousOffset, limit: previousLimit)
        } else {
            previousRequest = nil
        }

        let nextRequest: HandshakeRequest?
        if request.limit == nil || handshakes.count < request.limit! {
            nextRequest = nil
        } else {
            let nextOffset = request.offset + request.limit!
            nextRequest = HandshakeRequest(filterOption: request.filterOption, offset: nextOffset, limit: request.limit)
        }

        return HandshakeResponse(handshakes: handshakes, offset: request.offset, limit: request.limit, previousRequest: previousRequest, nextRequest: nextRequest)
    }
}

public struct HandshakeRequest {
    public struct FilterOption: OptionSet {
        public let rawValue: Int
        public static let hasKnownCaseAssociated = FilterOption(rawValue: 1 << 0)
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public enum SortingOption {
        case ascendingTimestamp
        case descendingTimestamp
    }

    public let filterOption: FilterOption
    public let sortingOption: SortingOption
    public let offset: Int
    public let limit: Int?
    public init(filterOption: FilterOption = [], sortingOption: SortingOption = .descendingTimestamp, offset: Int = 0, limit: Int? = nil) {
        self.filterOption = filterOption
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

private extension Date {
    var dayMax: Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = calendar.dateComponents([.year, .day, .month, .hour, .minute, .second], from: self)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components)!
    }

    var dayMin: Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .day, .month], from: self)
        return calendar.date(from: components)!
    }
}
