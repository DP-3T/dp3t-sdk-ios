/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Date model wich is always rounded to just contain the current day
struct DayDate: Codable, CustomStringConvertible, Equatable {
    let timestamp: TimeInterval

    init(date: Date = Date()) {
        var calendar = Calendar.current
        calendar.timeZone = CryptoConstants.timeZone
        let components = calendar.dateComponents([.year, .day, .month], from: date)
        timestamp = calendar.date(from: components)!.timeIntervalSince1970
    }

    public func getNext() -> DayDate {
        let nextDay = Date(timeIntervalSince1970: timestamp).addingTimeInterval(.day)
        return DayDate(date: nextDay)
    }

    public func isBefore(other: Date) -> Bool {
        return timestamp < other.timeIntervalSince1970
    }

    public func isBefore(other: DayDate) -> Bool {
        return timestamp < other.timestamp
    }

    var description: String {
        return "<DayDate \(Date(timeIntervalSince1970: timestamp))>"
    }
}
