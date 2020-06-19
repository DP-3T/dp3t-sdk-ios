/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
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

    var period: UInt32 {
        return UInt32(timestamp / (10 * .minute))
    }
}
