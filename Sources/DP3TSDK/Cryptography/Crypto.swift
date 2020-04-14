/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CommonCrypto
import Foundation

public class Crypto {
    public static func sha256(_ data: Data) -> Data {
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes { rawMutableBufferPointer in
            let bufferPointer = rawMutableBufferPointer.bindMemory(to: UInt8.self)
            _ = data.withUnsafeBytes {
                CC_SHA256($0.baseAddress, UInt32(data.count), bufferPointer.baseAddress)
            }
        }
        return digest
    }

    /// Perform an HMAC function on a message using a secret key
    /// - Parameters:
    ///   - msg: The message to be hashed
    ///   - key: The key to use for the hash
    public static func hmac(msg: Data, key: Data) -> Data {
        var macData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        macData.withUnsafeMutableBytes { macBytes in
            msg.withUnsafeBytes { msgBytes in
                key.withUnsafeBytes { keyBytes in
                    guard let keyAddress = keyBytes.baseAddress,
                        let msgAddress = msgBytes.baseAddress,
                        let macAddress = macBytes.baseAddress
                    else { return }
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                           keyAddress, key.count, msgAddress,
                           msg.count, macAddress)
                    return
                }
            }
        }
        return macData
    }

    class AESCTREncrypt {
        let keyData: Data

        let keyLength: Int

        var cryptor: CCCryptorRef?

        init(keyData: Data) throws {
            self.keyData = keyData

            keyLength = keyData.count

            let status = keyData.withUnsafeBytes { keyBytes -> CCCryptorStatus in
                let keyBuffer: UnsafeRawPointer = keyBytes.baseAddress!
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
            if status != 0 {
                throw CrypoError.AESError
            }
        }

        deinit {
            CCCryptorRelease(cryptor)
        }

        func encrypt(data: Data) throws -> Data {
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

            if UInt32(cryptStatus) != UInt32(kCCSuccess) {
                throw CrypoError.AESError
            }

            return cryptData
        }
    }
}
