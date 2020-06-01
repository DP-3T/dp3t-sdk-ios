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
