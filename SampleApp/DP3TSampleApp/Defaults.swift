/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import DP3TSDK
import Foundation

/// UserDefaults Storage Singleton
class Default {
    static var shared = Default()
    var store = UserDefaults.standard

    /// Current infection status
    var identifierPrefix: String? {
        get {
            return store.string(forKey: "org.dpppt.sampleapp.identifierPrefix")
        }
        set(newValue) {
            store.set(newValue, forKey: "org.dpppt.sampleapp.identifierPrefix")
        }
    }

    enum TracingMode: Int {
        case none = 0
        case active = 1
    }

    var tracingMode: TracingMode {
        get {
            let mode = (store.object(forKey: "org.dpppt.sampleapp.tracingMode") as? Int) ?? 0
            return TracingMode(rawValue: mode) ?? .none
        }
        set(newValue) {
            store.set(newValue.rawValue, forKey: "org.dpppt.sampleapp.tracingMode")
        }
    }
}
