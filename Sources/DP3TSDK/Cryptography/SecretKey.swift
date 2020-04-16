/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

struct SecretKey: Codable, CustomStringConvertible {
    let day: SecretKeyDay
    let keyData: Data

    var description: String {
        return "<SecretKey_\(day): \(keyData.hexEncodedString)>"
    }
}

struct EphIDsForDay: Codable {
    let day: SecretKeyDay
    let ephIDs: [Data]
}
