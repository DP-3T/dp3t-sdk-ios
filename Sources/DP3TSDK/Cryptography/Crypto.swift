/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
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
