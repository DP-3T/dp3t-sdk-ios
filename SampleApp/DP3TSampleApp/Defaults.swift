/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
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
