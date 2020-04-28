/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CommonCrypto
import Foundation

/// Crypto erros
enum CryptoError: Error {
    case dataIntegrity
    case aesError(_ status: CCCryptorStatus)
}

/// class which handles all cryptographic operations fot the sdk
internal class Crypto {
    /// generates 32 bytes of random data
    /// - Throws: throws if a error happens
    /// - Returns: random data
    internal static func generateRandomKey() throws -> Data {
        var keyData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, Int(CC_SHA256_DIGEST_LENGTH), $0.baseAddress!)
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

    /// Perform an HMAC function on a message using a secret key
    /// - Parameters:
    ///   - msg: The message to be hashed
    ///   - key: The key to use for the hash
    /// - Returns: digest
    internal static func hmac(msg: Data, key: Data) -> Data {
        var macData = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        msg.withUnsafeBytes { msgBytes in
            key.withUnsafeBytes { keyBytes in
                guard let keyAddress = keyBytes.baseAddress,
                    let msgAddress = msgBytes.baseAddress
                else { return }
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyAddress, key.count, msgAddress,
                       msg.count, &macData)
                return
            }
        }
        return Data(macData)
    }

    /// performs AES encryption in CTR mode
    class AESCTREncrypt {
        private let keyData: Data

        private let keyLength: Int

        private var cryptor: CCCryptorRef?

        /// Initialize the encryptor
        /// - Parameter keyData: the key to use
        /// - Throws: throws if a error happens
        internal init(keyData: Data) throws {
            self.keyData = keyData
            keyLength = keyData.count

            let cryptStatus = keyData.withUnsafeBytes { keyBytes -> CCCryptorStatus in
                guard let keyBuffer = keyBytes.baseAddress else { return -1 }
                return CCCryptorCreateWithMode(CCOperation(kCCEncrypt),
                                               CCMode(kCCModeCTR),
                                               CCAlgorithm(kCCAlgorithmAES),
                                               CCPadding(ccNoPadding),
                                               nil,
                                               keyBuffer,
                                               keyLength,
                                               nil,
                                               0,
                                               0,
                                               CCOptions(kCCModeOptionCTR_BE),
                                               &cryptor)
            }
            if cryptStatus != kCCSuccess {
                throw CryptoError.aesError(cryptStatus)
            }
        }

        deinit {
            CCCryptorRelease(cryptor)
        }

        /// Update the stream cipher with given data
        /// - Parameter data: input data
        /// - Throws: throws if a error happens
        /// - Returns: encrypted data
        internal func encrypt(data: Data) throws -> Data {
            var cryptData = Data(count: data.count)

            var numBytesEncrypted: size_t = 0

            let cryptStatus = cryptData.withUnsafeMutableBytes { cryptBytes -> CCCryptorStatus in
                let cryptBuffer: UnsafeMutableRawPointer = cryptBytes.baseAddress!
                return data.withUnsafeBytes { dataBytes -> CCCryptorStatus in
                    let dataBuffer: UnsafeRawPointer = dataBytes.baseAddress!
                    return CCCryptorUpdate(cryptor,
                                           dataBuffer,
                                           data.count,
                                           cryptBuffer,
                                           data.count,
                                           &numBytesEncrypted)
                }
            }

            if cryptStatus != kCCSuccess {
                throw CryptoError.aesError(cryptStatus)
            }

            return cryptData
        }
    }
}
