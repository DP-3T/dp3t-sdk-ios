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
    /// get EphIDs
    func getEphIDs() throws -> EphIDsForDay?
    /// set EphIDs
    func setEphIDs(_ object: EphIDsForDay) throws
    /// remove all object
    func removeAllObject()
}

/// used for storing SecretKeys and EphIDs in the Keychain
class SecureStorage: SecureStorageProtocol {

    private let keychain: Keychain

    private let secretKeyKey: Keychain.Key<[SecretKey]> = .init(key: "org.dpppt.keylist")
    private let ephIDsTodayKey: Keychain.Key<EphIDsForDay> = .init(key: "org.dpppt.ephsIDs")

    /// Initialize a secure storage with a given keychain
    /// - Parameter keychain: the keychain to use
    init(keychain: Keychain = Keychain()) {
        self.keychain = keychain
        if (Default.shared.isFirstLaunch) {
            Default.shared.isFirstLaunch = false
            self.removeAllObject()
        }
    }

    /// Get EphIDs
    /// - Throws: if a error happens
    /// - Returns: the retreived EphIDs
    func getEphIDs() throws -> EphIDsForDay? {
        let result = keychain.get(for: ephIDsTodayKey)
        switch result {
        case let .success(obj):
            return obj
        case let .failure(error):
            switch error {
            case .notFound:
                return nil
            case .decodingError:
                keychain.delete(for: ephIDsTodayKey)
                return nil
            default:
                throw error
            }
        }
    }

    /// Set EphIDs
    /// - Parameter object: the object to set
    /// - Throws: if a error happens
    func setEphIDs(_ object: EphIDsForDay) throws {
        let result = keychain.set(object, for: ephIDsTodayKey)
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
            case .decodingError:
                keychain.delete(for: secretKeyKey)
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
        keychain.delete(for: ephIDsTodayKey)
    }
}
