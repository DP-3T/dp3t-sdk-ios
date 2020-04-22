/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

enum NetworkingConstants {
    ///Formatter used in networking to specify days
    static let dayIdentifierFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = CryptoConstants.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    /// number of days to fetch for matching
    static let daysToFetch: Int = 14
    /// allowed client time inconsistency
    static let timeShiftThreshold: TimeInterval = 30 * .second
}
