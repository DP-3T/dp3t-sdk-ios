/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import CommonCrypto
import Foundation

/// class which handles all cryptographic operations fot the sdk
internal class Crypto {
    /// generates 32 bytes of random data
    /// - Throws: throws if a error happens
    /// - Returns: random data
    internal static func generateRandomKey(lenght: Int = Int(CC_SHA256_DIGEST_LENGTH)) throws -> Data {
        var keyData = Data(count: lenght)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, lenght, $0.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw KeychainError.cannotAccess(result)
        }
        return keyData
    }

    /// Perform the SHA256 hashing algorithm
    /// - Parameter data: input data
    /// - Returns: digest
    internal static func sha256(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }
}
