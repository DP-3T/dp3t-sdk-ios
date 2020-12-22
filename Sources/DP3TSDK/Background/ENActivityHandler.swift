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
import ExposureNotification

struct ENActivityFlags: OptionSet {
    let rawValue: UInt32

    /// The app launched to perform periodic operations.
    static let periodicRun = ENActivityFlags(rawValue: 1 << 2)
}

typealias ENActivityHandler = (ENActivityFlags) -> Void

@available(iOS 12.5, *)
extension ENManager {
    func setLaunchActivityHandler(activityHandler: @escaping ENActivityHandler) {
        let proxyActivityHandler: @convention(block) (UInt32) -> Void = {integerFlag in
            activityHandler(ENActivityFlags(rawValue: integerFlag))
        }
        setValue(proxyActivityHandler, forKey: "activityHandler")
    }
}
