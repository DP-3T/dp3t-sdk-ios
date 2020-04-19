/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CommonCrypto
import Foundation

/// Implements the ephID and secretkey handling
/// as specified in https://github.com/DP-3T/documents
class DP3TCryptoModule {

    private let store: SecureStorageProtocol

    /// Initilized the module
    /// - Parameter store: storage to use to persist secretkeys and ephIDs
    init(store: SecureStorageProtocol = SecureStorage()) throws {
        self.store = store
        do {
            let keys = try store.getSecretKeys()
            if keys.isEmpty {
                try generateInitialSecretKey()
            }
        } catch KeychainError.notFound {
            try generateInitialSecretKey()
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
        let nextDay = firstKey.day.getNext()
        let sKt1 = getSKt1(SKt0: firstKey.keyData)
        keys.insert(SecretKey(day: nextDay, keyData: sKt1), at: 0)
        let keysToStore = Array(keys.prefix(CryptoConstants.numberOfDaysToKeepData))
        try store.setSecretKeys(keysToStore)
    }

    /// get secret day of given day
    /// - Parameter day: optional day for secret key, defaults to today
    /// - Throws: throws if a error occurs
    /// - Returns: the secret key
    internal func getCurrentSK(day: DayDate = DayDate()) throws -> Data {
        var keys = try store.getSecretKeys()
        if let key = keys.first(where: { $0.day == day }){
            return key.keyData
        }
        while keys.first!.day < day {
            try rotateSK()
            keys = try store.getSecretKeys()
        }
        guard let firstKey = keys.first,
              firstKey.day.timestamp == day.timestamp else {
            throw CryptoError.dataIntegrity
        }
        return firstKey.keyData
    }

    /// generates ephIDs based on secret key
    /// - Parameter secretKey: secret key to base ephIDs on
    /// - Throws: throws if a error happens
    /// - Returns: the ephIDs
    internal static func createEphIDs(secretKey: Data) throws -> [EphID] {
        let hmac = Crypto.hmac(msg: CryptoConstants.broadcastKey, key: secretKey)

        let zeroData = Data(count: CryptoConstants.keyLenght * CryptoConstants.numberOfEpochsPerDay)

        let aes = try Crypto.AESCTREncrypt(keyData: hmac)

        var ephIDs = [Data]()
        let prgData = try aes.encrypt(data: zeroData)
        for i in 0 ..< CryptoConstants.numberOfEpochsPerDay {
            let pos = i * CryptoConstants.keyLenght
            ephIDs.append(prgData[pos ..< pos + CryptoConstants.keyLenght])
        }

        ephIDs.shuffle()

        return ephIDs
    }

    /// retrieves the ephIDs for a given day
    ///  either from storage or they get generate on demand
    /// - Parameter day: optional day for ephIDs, defaults to today
    /// - Throws: throws if a error happens
    /// - Returns: the ephIDs
    private func getEphIDsForToday(day: DayDate = DayDate()) throws -> [EphID] {
        var stored = try? store.getEphIDs()
        if stored == nil || stored?.day != day {
            let currentSk = try getCurrentSK(day: day)
            let ephIDs = try DP3TCryptoModule.createEphIDs(secretKey: currentSk)
            stored = EphIDsForDay(day: day, ephIDs: ephIDs)
            try store.setEphIDs(stored!)
        }
        return stored!.ephIDs
    }

    /// retrieve current ephID
    /// - Parameter timestamp: optional timestamp for ephIDs, defaults to now
    /// - Throws: throws if a error happens
    /// - Returns: the ephID
    internal func getCurrentEphID(timestamp: Date = Date()) throws -> EphID {
        let day = DayDate(date: timestamp)
        let ephIDs = try getEphIDsForToday(day: day)
        let counter = DP3TCryptoModule.getEpochCounter(day: day, timestamp: timestamp)
        return ephIDs[counter]
    }

    /// get the epoch counter by given day and timestamp
    /// - Parameters:
    ///   - day: the day
    ///   - timestamp: the timestamp
    /// - Returns: the count of the current epoch
    public static func getEpochCounter(day: DayDate, timestamp: Date) -> Int {
        return Int((timestamp.timeIntervalSince1970 - day.timestamp) / Double(CryptoConstants.secondsPerEpoch))
    }

    /// get the timestamp when the current epoch started
    public static func getCurrentEpochStart() -> Date {
        let currentDay = DayDate()
        let counter = DP3TCryptoModule.getEpochCounter(day: currentDay, timestamp: Date())
        return currentDay.dayMin.addingTimeInterval(Double(counter * Int(CryptoConstants.secondsPerEpoch)))
    }

    /// check if we had handshakes with a contact given its secretkey
    /// - Parameters:
    ///   - secretKey: the secret key of the contact
    ///   - onsetDate: the day on which onwards the contact published its secret key
    ///   - bucketDate: the day on which the contact published its secret key
    ///   - getContacts: a callback to retreive contacts for a given day
    /// - Throws: throws if a error occurs
    /// - Returns: all contacts that match
    internal func checkContacts(secretKey: Data, onsetDate: DayDate, bucketDate: DayDate, getContacts: (DayDate) -> ([Contact])) throws -> [Contact] {
        var dayToTest: DayDate = onsetDate
        var secretKeyForDay: Data = secretKey
        var matchingContacts: [Contact] = []
        while dayToTest <= bucketDate {
            let contactsOnDay = getContacts(dayToTest)
            guard !contactsOnDay.isEmpty else {
                dayToTest = dayToTest.getNext()
                secretKeyForDay = getSKt1(SKt0: secretKeyForDay)
                continue
            }

            // generate all ephIDs for day
            let ephIDs = Set(try DP3TCryptoModule.createEphIDs(secretKey: secretKeyForDay))
            // check all handshakes if they match any of the ephIDs
            for contact in contactsOnDay {
                if ephIDs.contains(contact.ephID) {
                    matchingContacts.append(contact)
                }
            }

            // update day to next day and rotate sk accordingly
            dayToTest = dayToTest.getNext()
            secretKeyForDay = getSKt1(SKt0: secretKeyForDay)
        }
        return matchingContacts
    }

    /// retreives the secret key to publich for a given day
    /// - Parameter onsetDate: the day
    /// - Throws: throws if a error happens
    /// - Returns: the secret key
    internal func getSecretKeyForPublishing(onsetDate: Date) throws -> Data? {
        let keys = try store.getSecretKeys()
        let day = DayDate(date: onsetDate)
        for key in keys {
            if key.day == day {
                return key.keyData
            }
        }
        if let last = keys.last,
            day < last.day {
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
        try store.setSecretKeys([SecretKey(day: DayDate(), keyData: keyData)])
    }
}
