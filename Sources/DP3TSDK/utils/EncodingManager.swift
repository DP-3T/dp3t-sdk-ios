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

enum EncodingManager {
    static func encode<T: Encodable>(object: T) throws -> Data {
        if #available(iOS 13.0, *) {
            return try JSONEncoder().encode(object)
        } else {
            // Fallback for iOS 12
            //https://github.com/apple/swift/pull/30615/files#diff-20486a3e986e2ca169265f8fb80e4e834bfbf4a1a691e109474391e7fd4c608aL257
            return try JSONSerialization.data(withJSONObject: object, options: .fragmentsAllowed)
        }
    }
}
