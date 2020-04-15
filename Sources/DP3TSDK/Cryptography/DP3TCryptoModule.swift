/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CommonCrypto
import Foundation

class DP3TCryptoModule {
    private let store: SecureStorageProtocol

    init?(store: SecureStorageProtocol = SecureStorage()) {
        self.store = store
        do {
            let keys = try store.getSecretKeys()
            if keys.isEmpty {
                try generateInitialSecretKey()
            }
        } catch KeychainError.notFound {
            do {
                try generateInitialSecretKey()
            } catch {
                return nil
            }
        } catch KeychainError.cannotAccess {
            return nil
        } catch {
            return nil
        }
    }

    private func getSKt1(SKt0: Data) -> Data {
        return Crypto.sha256(SKt0)
    }

    private func rotateSK() throws {
        var keys = try store.getSecretKeys()
        guard let firstKey = keys.first else {
            throw CryptoError.dataIntegrity
        }
        let nextEpoch = firstKey.epoch.getNext()
        let sKt1 = getSKt1(SKt0: firstKey.keyData)
        keys.insert(SecretKey(epoch: nextEpoch, keyData: sKt1), at: 0)
        while keys.count > CryptoConstants.numberOfDaysToKeepData {
            _ = keys.popLast()
        }
        try store.setSecretKeys(keys)
    }

    public func getCurrentSK(day: Epoch) throws -> Data {
        var keys = try store.getSecretKeys()
        while keys.first!.epoch.isBefore(other: day) {
            try rotateSK()
            keys = try store.getSecretKeys()
        }
        guard let firstKey = keys.first else {
            throw CryptoError.dataIntegrity
        }
        assert(firstKey.epoch.timestamp == day.timestamp)
        return firstKey.keyData
    }

    public func createEphIds(secretKey: Data) throws -> [Data] {
        let hmac = Crypto.hmac(msg: CryptoConstants.broadcastKey, key: secretKey)

        let zeroData = Data(count: CryptoConstants.keyLenght * CryptoConstants.numberOfEpochsPerDay)

        let aes = try Crypto.AESCTREncrypt(keyData: hmac)

        var ephIds = [Data]()
        let prgData = try aes.encrypt(data: zeroData)
        for i in 0 ..< CryptoConstants.numberOfEpochsPerDay {
            let pos = i * CryptoConstants.keyLenght
            ephIds.append(prgData[pos ..< pos + CryptoConstants.keyLenght])
        }

        ephIds.shuffle()

        return ephIds
    }

    func getEphidsForToday(epoch: Epoch) throws -> [Data] {
        var stored = try? store.getEphIds()
        if stored == nil || stored?.epoch != epoch {
            let currentSk = try getCurrentSK(day: epoch)
            let ephIds = try createEphIds(secretKey: currentSk)
            stored = EphIdsForDay(epoch: epoch, ephIds: ephIds)
            try store.setEphIds(stored!)
        }
        return stored!.ephIds
    }

    public func getCurrentEphId() throws -> Data {
        let epoch = Epoch()
        let ephIds = try getEphidsForToday(epoch: epoch)
        let counter = Int((Date().timeIntervalSince1970 - epoch.timestamp) / Double(CryptoConstants.millisecondsPerEpoch))
        return ephIds[counter]
    }

    public func checkContacts(secretKey: Data, onsetDate: Epoch, bucketDate: Epoch, getHandshake: (Date) -> ([HandshakeModel])) throws -> HandshakeModel? {
        var dayToTest: Epoch = onsetDate
        var secretKeyForDay: Data = secretKey
        while dayToTest.timestamp <= bucketDate.timestamp {
            let handshakesOnDay = getHandshake(Date(timeIntervalSince1970: dayToTest.timestamp))
            guard !handshakesOnDay.isEmpty else {
                dayToTest = dayToTest.getNext()
                secretKeyForDay = getSKt1(SKt0: secretKeyForDay)
                continue
            }

            // generate all ephIds for day
            let ephIds = try createEphIds(secretKey: secretKeyForDay)
            // check all handshakes if they match any of the ephIds
            for handshake in handshakesOnDay {
                for ephId in ephIds {
                    if handshake.ephid == ephId {
                        return handshake
                    }
                }
            }

            // update day to next day and rotate sk accordingly
            dayToTest = dayToTest.getNext()
            secretKeyForDay = getSKt1(SKt0: secretKeyForDay)
        }
        return nil
    }

    public func getSecretKeyForPublishing(onsetDate: Date) throws -> Data? {
        let keys = try store.getSecretKeys()
        let epoch = Epoch(date: onsetDate)
        for key in keys {
            if key.epoch == epoch {
                return key.keyData
            }
        }
        if let last = keys.last,
            epoch.isBefore(other: last.epoch) {
            return last.keyData
        }
        return nil
    }

    public func reset() {
        store.removeAllObject()
    }

    private func generateInitialSecretKey() throws {
        let keyData = try generateRandomKey()
        try store.setSecretKeys([SecretKey(epoch: Epoch(), keyData: keyData)])
    }

    private func generateRandomKey() throws -> Data {
        var keyData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, Int(CC_SHA256_DIGEST_LENGTH), $0.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw KeychainError.cannotAccess(result)
        }
        return keyData
    }
}
