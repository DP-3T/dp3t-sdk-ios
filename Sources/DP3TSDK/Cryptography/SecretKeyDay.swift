/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

struct SecretKeyDay: Codable, CustomStringConvertible, Equatable {
    let timestamp: TimeInterval

    init(date: Date = Date()) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .day, .month], from: date)
        timestamp = calendar.date(from: components)!.timeIntervalSince1970
    }

    public func getNext() -> SecretKeyDay {
        let nextDay = Date(timeIntervalSince1970: timestamp).addingTimeInterval(.day)
        return SecretKeyDay(date: nextDay)
    }

    public func isBefore(other: Date) -> Bool {
        return timestamp < other.timeIntervalSince1970
    }

    public func isBefore(other: SecretKeyDay) -> Bool {
        return timestamp < other.timestamp
    }

    var description: String {
        return "<SecretKeyDay\(Date(timeIntervalSince1970: timestamp))>"
    }
}
