/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Model of the exposed person
struct ExposeeModel: Encodable {
    /// Secret key used to generate EphID (base64 encoded)
    let key: Data

    /// The onset date
    let onset: DayDate

    /// Authentication data provided by health institutes to verify test results
    let authData: String?

    let fake: Bool

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode key
        try container.encode(key, forKey: .key)
        // Encode auth if present only
        try container.encodeIfPresent(authData, forKey: .authData)
        // Compute date
        let startOfDayTimestamp = Int(onset.dayMin.millisecondsSince1970)
        try container.encode(startOfDayTimestamp, forKey: .onset)

        try container.encode(fake ? 1 : 0, forKey: .fake)
    }

    enum CodingKeys: CodingKey {
        case key, onset, authData, fake
    }
}
