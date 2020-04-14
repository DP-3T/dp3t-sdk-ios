/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

struct SecretKey: Codable, CustomStringConvertible {
    let epoch: Epoch
    let keyData: Data

    var description: String {
        return "<SecretKey_\(epoch): \(keyData.hexEncodedString)>"
    }
}

struct EphIdsForDay: Codable {
    let epoch: Epoch
    let ephIds: [Data]
}
