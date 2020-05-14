/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

struct DelayedKeyModel: Encodable {

    let delayedKey: CodableDiagnosisKey

    let fake: Bool

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode key
        try container.encode(delayedKey, forKey: .delayedKey)

        try container.encode(fake ? 1 : 0, forKey: .fake)
    }

    enum CodingKeys: CodingKey {
        case delayedKey, fake
    }
}
