/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import Foundation

class MockKeychain: KeychainProtocol {
    var store: [String: Any] = [:]
    func get<T: Codable>(for key: KeychainKey<T>) -> Result<T, KeychainError> {
        if let i = store[key.key] as? T {
            return .success(i)
        }
        return .failure(.notFound)
    }

    func set<T>(_ object: T, for key: KeychainKey<T>) -> Result<Void, KeychainError>  {
        store[key.key] = object
        return .success(())
    }

    func delete<T>(for key: KeychainKey<T>) -> Result<Void, KeychainError> {
        store[key.key] = nil
        return .success(())
    }

    func reset(){
        store.removeAll()
    }
}
