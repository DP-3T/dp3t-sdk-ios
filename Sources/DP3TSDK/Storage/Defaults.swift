/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation

protocol DefaultStorage {
    /// stores if this is the first launch of the SDK
    var isFirstLaunch: Bool { get set }

    /// Last date a backend sync happend
    var lastSync: Date? { get set }

    var lastSyncSinceTimestamp: Date? { get set }

    /// Current infection status
    var didMarkAsInfected: Bool { get set }

    /// Parameters to configure the SDK
    var parameters: DP3TParameters { get set }

    var exposureDetectionDates: [Date] { get set }

    var infectionStatusIsResettable: Bool { get set }

    func reset()
}

/// UserDefaults Storage Singleton
class Default: DefaultStorage {
    static var shared = Default()
    var store = UserDefaults.standard

    /// stores if this is the first launch of the SDK
    @Persisted(userDefaultsKey: "org.dpppt.firstlaunch", defaultValue: true)
    var isFirstLaunch: Bool

    /// Last date a backend sync happend
    @Persisted(userDefaultsKey: "org.dpppt.lastsync", defaultValue: nil)
    var lastSync: Date?

    @Persisted(userDefaultsKey: "org.dpppt.lastSyncSinceTimestamp", defaultValue: nil)
    var lastSyncSinceTimestamp: Date?

    /// Current infection status
    @KeychainPersisted(key: "org.dpppt.didMarkAsInfected", defaultValue: false)
    var didMarkAsInfected: Bool

    @Persisted(userDefaultsKey: "org.dpppt.exposureDetectionDates", defaultValue: [])
    var exposureDetectionDates: [Date]

    /// Is infection status resettable
    /// on iOS > 13.7 we need to delay to disable of tracing until OutstandingPublishOperation is finished
    @KeychainPersisted(key: "org.dpppt.infectionStatusIsResettable", defaultValue: true)
    var infectionStatusIsResettable: Bool

    /// Parameters
    private func saveParameters(_ parameters: DP3TParameters) {
        let encoder = JSONEncoder()

        if let encoded = try? encoder.encode(parameters) {
            store.set(encoded, forKey: "org.dpppt.parameters")
        }
    }

    private var parametersCache: DP3TParameters? {
        didSet {
            guard oldValue != nil, let parametersCache = parametersCache else { return }
            saveParameters(parametersCache)
        }
    }

    var parameters: DP3TParameters {
        get {
            if let cache = parametersCache {
                return cache
            }

            guard let obj = store.object(forKey: "org.dpppt.parameters") as? Data else {
                parametersCache = .init()
                saveParameters(parametersCache!)
                return parametersCache!
            }

            let decoder = JSONDecoder()

            guard let decoded = try? decoder.decode(DP3TParameters.self, from: obj) else {
                parametersCache = .init()
                saveParameters(parametersCache!)
                return parametersCache!
            }

            guard decoded.version == DP3TParameters.parameterVersion else {
                parametersCache = .init()
                saveParameters(parametersCache!)
                return parametersCache!
            }

            parametersCache = decoded
            return parametersCache!
        }
        set(newValue) {
            parametersCache = newValue
        }
    }

    func reset() {
        parameters = .init()
        lastSync = nil
        didMarkAsInfected = false
        lastSyncSinceTimestamp = nil
    }
}

@propertyWrapper
class Persisted<Value: Codable> {
    init(userDefaultsKey: String, defaultValue: Value) {
        self.userDefaultsKey = userDefaultsKey
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                wrappedValue = try JSONDecoder().decode(Value.self, from: data)
            } catch {
                wrappedValue = defaultValue
            }
        } else {
            wrappedValue = defaultValue
        }
    }

    let userDefaultsKey: String

    var wrappedValue: Value {
        didSet {
            UserDefaults.standard.set(try! JSONEncoder().encode(wrappedValue), forKey: userDefaultsKey)
        }
    }
}

@propertyWrapper
class KeychainPersisted<Value: Codable> {
    init(key: String, defaultValue: Value, keychain: KeychainProtocol = Keychain()) {
        self.keychain = keychain
        self.key = KeychainKey(key: key)
        switch keychain.get(for: self.key) {
        case let .success(value):
            wrappedValue = value
        case .failure:
            wrappedValue = defaultValue
        }
    }

    let keychain: KeychainProtocol
    let key: KeychainKey<Value>

    var wrappedValue: Value {
        didSet {
            keychain.set(wrappedValue, for: key)
        }
    }
}
