/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

public typealias EphID = Data

struct SecretKey: Codable, CustomStringConvertible {
    let day: DayDate
    let keyData: Data

    var description: String {
        return "<SecretKey_\(day): \(keyData.hexEncodedString)>"
    }
}

struct EphIDsForDay: Codable {
    let day: DayDate
    let ephIDs: [EphID]
}
