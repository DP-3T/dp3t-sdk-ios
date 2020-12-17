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
        if #available(iOS 13.1, *) {
            return try JSONEncoder().encode(object)
        } else {
            // workaround if object is top level to support pre 13.1
            if T.self == Optional<Date>.self ||
               T.self == Optional<Bool>.self ||
                T.self == Date.self ||
                T.self == Bool.self ||
                T.self == String.self ||
                T.self == Optional<String>.self {
                let encodedDate = try JSONEncoder().encode([object])
                var encodedString = String(data: encodedDate, encoding: .utf8)
                //remove "[" and "]"
                encodedString?.removeLast()
                encodedString?.removeFirst()
                return encodedString!.data(using: .utf8)!
            } else {
                return try JSONEncoder().encode(object)
            }
        }
    }
}
