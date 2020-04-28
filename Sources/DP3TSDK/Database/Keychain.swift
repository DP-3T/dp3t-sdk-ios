/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Keychain Errors
enum KeychainError: Error {
    /// Object could not be encoded
    case encodingError(_ error: Error)
    /// Object could not be decoded
    case decodingError(_ error: Error)
    /// A error happend while storing the object
    case storingError(_ status: OSStatus)
    /// The object was not found
    case notFound
    /// a Access error happend
    case cannotAccess(_ status: OSStatus)
    /// a deletion error happend
    case cannotDelete(_ status: OSStatus)
}

/// A wrapper class for the keychain
class Keychain {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// This is struct is needed to defer the type of a key when getting a object
    struct Key<Object: Codable> {
        let key: String
        init(key: String) {
            self.key = key
        }
    }

    /// Get a object from the keychain
    /// - Parameter key: a key object with the type
    /// - Returns: a result which either contain the error or the object
    public func get<T: Codable>(for key: Key<T>) -> Result<T, KeychainError> {
        var query = self.query(for: key)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecItemNotFound:
            return .failure(.notFound)
        case noErr:
            guard let item = item as? Data else {
                fatalError("Keychain not returning Data")
            }
            do {
                let object = try JSONDecoder().decode(T.self, from: item)
                return .success(object)
            } catch {
                return .failure(.decodingError(error))
            }
        default:
            return .failure(.cannotAccess(status))
        }
    }

    /// Set a object to the keychain
    /// - Parameters:
    ///   - object: the object to set
    ///   - key: the keyobject to use
    /// - Returns: a result which either is successful or contains the error
    @discardableResult
    public func set<T: Codable>(_ object: T, for key: Key<T>) -> Result<Void, KeychainError> {
        let data: Data
        do {
            data = try encoder.encode(object)
        } catch {
            return .failure(.encodingError(error))
        }
        var query = self.query(for: key)
        query[kSecValueData] = data

        var status: OSStatus = SecItemCopyMatching(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            // Item exists so we can update it
            let attributes = [kSecValueData: data]
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status != errSecSuccess {
                return .failure(.storingError(status))
            } else {
                return .success(())
            }
        case errSecItemNotFound:
            // First time setting item
            status = SecItemAdd(query as CFDictionary, nil)

            if status != noErr {
                return .failure(.storingError(status))
            }
            return .success(())
        default:
            return .failure(.storingError(status))
        }
    }

    /// Deletes a object from the keychain
    /// - Parameter key: the key to delete
    /// - Returns: a result which either is successful or contains the error
    @discardableResult
    public func delete<T>(for key: Key<T>) -> Result<Void, KeychainError> {
        let query = self.query(for: key)

        let status: OSStatus = SecItemDelete(query as CFDictionary)
        switch status {
        case noErr, errSecItemNotFound:
            return .success(())
        default:
            return .failure(.cannotDelete(status))
        }
    }

    /// helpermethod to construct the keychain query
    /// - Parameter key: key to use
    /// - Returns: the keychain query
    private func query<T>(for key: Key<T>) -> [CFString: Any] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword as String,
            kSecAttrAccount: key.key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return query
    }
}
