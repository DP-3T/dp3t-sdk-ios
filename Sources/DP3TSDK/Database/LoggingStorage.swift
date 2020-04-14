/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SQLite

#if CALIBRATION
    public struct LogEntry: Identifiable {
        public let id: Int
        public let timestamp: Date
        public let type: LogType
        public let message: String
    }

    public struct LogRequest {
        public enum Sorting {
            case asc
            case desc
        }

        public let sorting: Sorting
        public var offset: Int
        public var limit: Int

        public init(sorting: Sorting = .asc, offset: Int = 0, limit: Int = 1000) {
            self.sorting = sorting
            self.offset = offset
            self.limit = limit
        }
    }

    public struct LogResponse {
        public let logs: [LogEntry]
        public let nextRequest: LogRequest?
        fileprivate init(logs: [LogEntry], nextRequest: LogRequest?) {
            self.logs = logs
            self.nextRequest = nextRequest
        }
    }

    /// Storage used to persist Logs
    class LoggingStorage {
        /// Database connection
        private let database: Connection

        /// Name of the table
        let table = Table("logs")

        /// Column definitions
        let idColumn = Expression<Int>("id")
        let timestampColumn = Expression<Date>("timestamp")
        let typeColumn = Expression<Int>("type")
        let messageColumn = Expression<String>("message")

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
                t.column(timestampColumn)
                t.column(typeColumn)
                t.column(messageColumn)
        })
        }

        func log(type: LogType, message: String) throws -> LogEntry {
            let timestamp = Date()
            let insert = table.insert(
                timestampColumn <- timestamp,
                typeColumn <- type.rawValue,
                messageColumn <- message
            )
            try database.run(insert)
            return LogEntry(id: 0, timestamp: timestamp, type: type, message: message)
        }

        /// Delete all entries
        func emptyStorage() throws {
            try database.run(table.delete())
        }

        /// count of entries
        func count() throws -> Int {
            try database.scalar(table.count)
        }

        func getLogs(_ request: LogRequest) throws -> LogResponse {
            assert(request.limit > 0, "Limits should be at least one")
            assert(request.offset >= 0, "Offset must be positive")

            var query = table

            switch request.sorting {
            case .asc:
                query = query.order(timestampColumn.asc)
            case .desc:
                query = query.order(timestampColumn.desc)
            }

            query = query.limit(request.limit, offset: request.offset)

            var logs: [LogEntry] = []
            for row in try database.prepare(query) {
                logs.append(LogEntry(id: row[idColumn], timestamp: row[timestampColumn], type: LogType(rawValue: row[typeColumn]) ?? .none, message: row[messageColumn]))
            }

            var nextRequest: LogRequest?
            if logs.count < request.limit {
                nextRequest = nil
            } else {
                let nextOffset = request.offset + request.limit
                nextRequest = LogRequest(sorting: request.sorting, offset: nextOffset, limit: request.limit)
            }

            return LogResponse(logs: logs, nextRequest: nextRequest)
        }
    }
#endif
