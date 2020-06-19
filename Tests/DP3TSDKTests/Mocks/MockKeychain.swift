/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
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

    func set<T>(_ object: T, for key: KeychainKey<T>) -> Result<Void, KeychainError> {
        store[key.key] = object
        return .success(())
    }

    func delete<T>(for key: KeychainKey<T>) -> Result<Void, KeychainError> {
        store[key.key] = nil
        return .success(())
    }

    func reset() {
        store.removeAll()
    }
}
