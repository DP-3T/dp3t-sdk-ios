/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// UserDefaults Storage Singleton
class Default {
    static var shared = Default()
    var store = UserDefaults.standard

    /// Last date a backend sync happend
    var lastSync: Date? {
        get {
            return store.object(forKey: "org.dpppt.lastsync") as? Date
        }
        set(newValue) {
            store.set(newValue, forKey: "org.dpppt.lastsync")
        }
    }

    /// Current infection status
    var infectionStatus: InfectionStatus {
        get {
            return InfectionStatus(rawValue: store.integer(forKey: "org.dpppt.InfectionStatus")) ?? .healthy
        }
        set(newValue) {
            store.set(newValue.rawValue, forKey: "org.dpppt.InfectionStatus")
        }
    }
}
