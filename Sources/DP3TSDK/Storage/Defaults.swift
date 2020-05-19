/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

protocol DefaultStorage {
    /// stores if this is the first launch of the SDK
    var isFirstLaunch: Bool { get set }

    /// Last date a backend sync happend
    var lastSync: Date? { get set }

    /// Last batch release time which was loaded
    /// If nil .now should be used since it is not neccessary to load all past batches
    var installationDate: Date? { get set }

    var publishedAfterStore: [Date: Date] { get set }

    /// Current infection status
    var didMarkAsInfected: Bool { get set }

    /// Parameters to configure the SDK
    var parameters: DP3TParameters { get set }
}

/// UserDefaults Storage Singleton
class Default: DefaultStorage {
    static var shared = Default()
    var store = UserDefaults.standard

    /// stores if this is the first launch of the SDK
    @Persisted(userDefaultsKey: "org.dpppt.firstlaunch", defaultValue: false)
    var isFirstLaunch: Bool

    /// Last date a backend sync happend
    @Persisted(userDefaultsKey: "org.dpppt.lastsync", defaultValue: nil)
    var lastSync: Date?

    @Persisted(userDefaultsKey: "org.dpppt.installationDate", defaultValue: nil)
    var installationDate: Date?

    @Persisted(userDefaultsKey: "org.dpppt.publishedAfterStore", defaultValue: [:])
    var publishedAfterStore: [Date: Date]

    /// Current infection status
    @KeychainPersisted(key: "org.dpppt.didMarkAsInfected", defaultValue: false)
    var didMarkAsInfected: Bool

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

    func reset(){
        parameters = .init()
        lastSync = nil
        installationDate = nil
        didMarkAsInfected = false
        publishedAfterStore = [:]
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
