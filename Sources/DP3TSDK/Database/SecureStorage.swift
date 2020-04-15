/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// StorageProtcol used for testing
protocol SecureStorageProtocol {
    /// get the secret keys
    func getSecretKeys() throws -> [SecretKey]
    /// set secret keys
    func setSecretKeys(_ object: [SecretKey]) throws
    /// get EphIds
    func getEphIds() throws -> EphIdsForDay?
    /// set EphIds
    func setEphIds(_ object: EphIdsForDay) throws
    /// remove all object
    func removeAllObject()
}

/// used for storing SecretKeys and EphIds in the Keychain
class SecureStorage: SecureStorageProtocol {

    private let keychain = Keychain()

    private let secretKeyKey: Keychain.Key<[SecretKey]> = .init(key: "org.dpppt.keylist")
    private let ephIdsTodayKey: Keychain.Key<EphIdsForDay> = .init(key: "org.dpppt.ephsIds")

    /// Get EphIds
    /// - Throws: if a error happens
    /// - Returns: the retreived EphIds
    func getEphIds() throws -> EphIdsForDay? {
        let result = keychain.get(for: ephIdsTodayKey)
        switch result {
        case let .success(obj):
            return obj
        case let .failure(error):
            switch error {
            case .notFound:
                return nil
            default:
                throw error
            }
        }
    }

    /// Set EphIds
    /// - Parameter object: the object to set
    /// - Throws: if a error happens
    func setEphIds(_ object: EphIdsForDay) throws {
        let result = keychain.set(object, for: ephIdsTodayKey)
        switch result {
        case .success(_):
            return
        case let .failure(error):
            throw error
        }
    }

    /// get Secret Keys
    /// - Throws: if a error happens
    /// - Returns: the retreived secret keys
    func getSecretKeys() throws -> [SecretKey] {
        let result = keychain.get(for: secretKeyKey)
        switch result {
        case let .success(obj):
            return obj
        case let .failure(error):
            switch error {
            case .notFound:
                return []
            default:
                throw error
            }
        }
    }

    /// sets the secret Keys
    /// - Parameter object: the object to set
    /// - Throws: if a error happens
    func setSecretKeys(_ object: [SecretKey]) throws {
        let result = keychain.set(object, for: secretKeyKey)
        switch result {
        case .success(_):
            return
        case let .failure(error):
            throw error
        }
    }

    /// Removes all object (managed by this class) from the Keychain
    func removeAllObject() {
        keychain.delete(for: secretKeyKey)
        keychain.delete(for: ephIdsTodayKey)
    }
}
