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
    var lastLoadedBatchReleaseTime: Date? { get set }

    /// Current infection status
    var didMarkAsInfected: Bool { get set }

    /// Parameters to configure the SDK
    var parameters: DP3TParameters { get set }

    /// Outstanding publish operations
    var outstandingPublishes: Set<OutstandingPublishOperation> { get set }
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

    /// Last batch release time which was loaded
    /// If nil .now should be used since it is not neccessary to load all past batches
    @Persisted(userDefaultsKey: "org.dpppt.lastLoadedBatchReleaseTime", defaultValue: nil)
    var lastLoadedBatchReleaseTime: Date?

    /// Current infection status
    @Persisted(userDefaultsKey: "org.dpppt.didMarkAsInfected", defaultValue: false)
    var didMarkAsInfected: Bool

    /// Outstanding publish operation
    @Persisted(userDefaultsKey: "org.dpppt.outstandingPublish", defaultValue: [])
    var outstandingPublishes: Set<OutstandingPublishOperation>

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
