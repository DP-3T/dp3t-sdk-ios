/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CommonCrypto
import Foundation

/// Implements the ephid and secretkey handling
/// as specified in https://github.com/DP-3T/documents
class DP3TCryptoModule {

    private let store: SecureStorageProtocol

    /// Initilized the module
    /// - Parameter store: storage to use to persist secretkeys and ephIds
    init?(store: SecureStorageProtocol = SecureStorage.shared) {
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

    /// method to generate a secret key based on its predecessor
    /// - Parameter SKt0: secret key predecessor
    /// - Returns: next secret key
    private func getSKt1(SKt0: Data) -> Data {
        return Crypto.sha256(SKt0)
    }

    /// Generates new secret key and discards oldest ones if we have more than CryptoConstants.numberOfDaysToKeepData stored
    /// - Throws: throws is a error happens
    private func rotateSK() throws {
        var keys = try store.getSecretKeys()
        guard let firstKey = keys.first else {
            throw CryptoError.dataIntegrity
        }
        let nextEpoch = firstKey.epoch.getNext()
        let sKt1 = getSKt1(SKt0: firstKey.keyData)
        keys.insert(SecretKey(epoch: nextEpoch, keyData: sKt1), at: 0)
        let keysToStore = Array(keys.prefix(CryptoConstants.numberOfDaysToKeepData))
        try store.setSecretKeys(keysToStore)
    }

    /// get secret day of given day
    /// - Parameter day: optional day for secret key, defaults to today
    /// - Throws: throws if a error occurs
    /// - Returns: the secret key
    internal func getCurrentSK(epoch: Epoch = Epoch()) throws -> Data {
        var keys = try store.getSecretKeys()
        while keys.first!.epoch.isBefore(other: epoch) {
            try rotateSK()
            keys = try store.getSecretKeys()
        }
        guard let firstKey = keys.first else {
            throw CryptoError.dataIntegrity
        }
        assert(firstKey.epoch.timestamp == epoch.timestamp)
        return firstKey.keyData
    }

    /// generates ephIds based on secret key
    /// - Parameter secretKey: secret key to base ephIds on
    /// - Throws: throws if a error happens
    /// - Returns: the ephids
    internal static func createEphIds(secretKey: Data) throws -> [Data] {
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

    /// retrieves the ephIds for a given day
    ///  either from storage or they get generate on demand
    /// - Parameter epoch: optional epoch for ephIds, defaults to today
    /// - Throws: throws if a error happens
    /// - Returns: the ephids
    private func getEphidsForToday(epoch: Epoch = Epoch()) throws -> [Data] {
        var stored = try? store.getEphIds()
        if stored == nil || stored?.epoch != epoch {
            let currentSk = try getCurrentSK(epoch: epoch)
            let ephIds = try DP3TCryptoModule.createEphIds(secretKey: currentSk)
            stored = EphIdsForDay(epoch: epoch, ephIds: ephIds)
            try store.setEphIds(stored!)
        }
        return stored!.ephIds
    }

    /// retrieve current ephId
    /// - Throws: throws if a error happens
    /// - Returns: the ephId
    internal func getCurrentEphId() throws -> Data {
        let epoch = Epoch()
        let ephIds = try getEphidsForToday(epoch: epoch)
        let counter = Int((Date().timeIntervalSince1970 - epoch.timestamp) / Double(CryptoConstants.millisecondsPerEpoch))
        return ephIds[counter]
    }

    /// check if we had handshakes with a contact given its secretkey
    /// - Parameters:
    ///   - secretKey: the secret key of the contact
    ///   - onsetDate: the day on which onwards the contact published its secret key
    ///   - bucketDate: the day on which the contact published its secret key
    ///   - getHandshake: a callback to retreive handshakes for a given day
    /// - Throws: throws if a error occurs
    /// - Returns: the first handshakes whose token matches the secret key
    internal func checkContacts(secretKey: Data, onsetDate: Epoch, bucketDate: Epoch, getHandshake: (Date) -> ([HandshakeModel])) throws -> HandshakeModel? {
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
            let ephIds = try DP3TCryptoModule.createEphIds(secretKey: secretKeyForDay)
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

    /// retreives the secret key to publich for a given day
    /// - Parameter onsetDate: the day
    /// - Throws: throws if a error happens
    /// - Returns: the secret key
    internal func getSecretKeyForPublishing(onsetDate: Date) throws -> Data? {
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

    /// reset data
    public func reset() {
        store.removeAllObject()
    }

    /// generate initial secret key
    /// - Throws: throws if a error occurs
    private func generateInitialSecretKey() throws {
        let keyData = try Crypto.generateRandomKey()
        try store.setSecretKeys([SecretKey(epoch: Epoch(), keyData: keyData)])
    }
}
