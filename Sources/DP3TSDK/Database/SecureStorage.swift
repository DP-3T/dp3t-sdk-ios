/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

enum KeychainError: Error {
    case notFound
    case cannotAccess
}

protocol SecureStorageProtocol {
    func getSecretKeys() throws -> [SecretKey]
    func setSecretKeys(_ object: [SecretKey]) throws
    func getEphIDs() throws -> EphIDsForDay?
    func setEphIDs(_ object: EphIDsForDay) throws
    func removeAllObject()
}

class SecureStorage: SecureStorageProtocol {
    static let shared = SecureStorage()

    private let secretKeyKey: String = "org.dpppt.keylist"
    private let ephIDsTodayKey: String = "org.dpppt.ephsIds"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {}

    func getEphIDs() throws -> EphIDsForDay? {
        let data = try get(for: ephIDsTodayKey)
        return try decoder.decode(EphIDsForDay.self, from: data)
    }

    func setEphIDs(_ object: EphIDsForDay) throws {
        let data = try encoder.encode(object)
        set(data, key: ephIDsTodayKey)
    }

    func getSecretKeys() throws -> [SecretKey] {
        let data = try get(for: secretKeyKey)
        return try decoder.decode([SecretKey].self, from: data)
    }

    func setSecretKeys(_ object: [SecretKey]) throws {
        let data = try encoder.encode(object)
        set(data, key: secretKeyKey)
    }

    private func set(_ data: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func get(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw KeychainError.notFound
        }
        guard status == errSecSuccess else {
            throw KeychainError.cannotAccess
        }
        return (item as! CFData) as Data
    }

    func removeAllObject() {
        do {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: secretKeyKey,
            ]
            SecItemDelete(query as CFDictionary)
        }
        do {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: ephIDsTodayKey,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
