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

    /// Current infection status
    var identifierPrefix: String? {
        get {
            return store.string(forKey: "org.dpppt.sampleapp.identifierPrefix")
        }
        set(newValue) {
            store.set(newValue, forKey: "org.dpppt.sampleapp.identifierPrefix")
        }
    }

    var reconnectionDelay: Int {
        get {
            return (store.object(forKey: "org.dpppt.sampleapp.reconnectionDelay") as? Int) ?? 60 * 2
        }
        set(newValue) {
            store.set(newValue, forKey: "org.dpppt.sampleapp.reconnectionDelay")
        }
    }

    var batchLenght: Double {
           get {
               return (store.object(forKey: "org.dpppt.sampleapp.batchLenght") as? Double) ?? 60 * 60 * 2
           }
           set(newValue) {
               store.set(newValue, forKey: "org.dpppt.sampleapp.batchLenght")
           }
       }

    enum TracingMode: Int {
        case none = 0
        case active = 1
        case activeReceiving = 2
        case activeAdvertising = 3
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
