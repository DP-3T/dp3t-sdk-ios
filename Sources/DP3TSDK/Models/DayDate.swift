/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Date model wich is always rounded to just contain the current day
struct DayDate: Codable, Equatable, Hashable {
    let timestamp: TimeInterval

    init(date: Date = Date()) {
        var calendar = Calendar.current
        calendar.timeZone = Default.shared.parameters.crypto.timeZone
        let components = calendar.dateComponents([.year, .day, .month], from: date)
        timestamp = calendar.date(from: components)!.timeIntervalSince1970
    }

    var dayMin: Date {
        return Date(timeIntervalSince1970: timestamp)
    }

    var dayMax: Date {
        return dayMin.addingTimeInterval(.day)
    }

    var period: UInt32 {
        return UInt32(timestamp / (10 * .minute))
    }
}
