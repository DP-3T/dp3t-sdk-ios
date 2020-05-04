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
}

/// UserDefaults Storage Singleton
class Default: DefaultStorage {
    static var shared = Default()
    var store = UserDefaults.standard

    /// stores if this is the first launch of the SDK
    var isFirstLaunch: Bool {
        get {
            return !store.bool(forKey: "org.dpppt.firstlaunch")
        }
        set(newValue) {
            store.set(!newValue, forKey: "org.dpppt.firstlaunch")
        }
    }

    /// Last date a backend sync happend
    var lastSync: Date? {
        get {
            return store.object(forKey: "org.dpppt.lastsync") as? Date
        }
        set(newValue) {
            store.set(newValue, forKey: "org.dpppt.lastsync")
        }
    }

    /// Last batch release time which was loaded
    /// If nil .now should be used since it is not neccessary to load all past batches
    var lastLoadedBatchReleaseTime: Date? {
        get {
            return store.object(forKey: "org.dpppt.lastLoadedBatchReleaseTime") as? Date
        }
        set(newValue) {
            store.set(newValue, forKey: "org.dpppt.lastLoadedBatchReleaseTime")
        }
    }

    /// Current infection status
    var didMarkAsInfected: Bool {
        get {
            return store.bool(forKey: "org.dpppt.didMarkAsInfected")
        }
        set(newValue) {
            store.set(newValue, forKey: "org.dpppt.didMarkAsInfected")
        }
    }

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
