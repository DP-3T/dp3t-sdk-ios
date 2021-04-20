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

@available(iOS 12.5, *)
class MockScanInstance: ENScanInstance {

    private var internalTypicalAttenuation: ENAttenuation

    private var internalSecondsSinceLastScan: Int

    init(typicalAttenuation: ENAttenuation, secondsSinceLastScan: Int) {
        internalTypicalAttenuation = typicalAttenuation
        internalSecondsSinceLastScan = secondsSinceLastScan
    }

    override var typicalAttenuation: ENAttenuation {
        get {
            internalTypicalAttenuation
        }
        set {
            internalTypicalAttenuation = newValue
        }
    }

    override var secondsSinceLastScan: Int {
        get {
            internalSecondsSinceLastScan
        }
        set {
            internalSecondsSinceLastScan = newValue
        }
    }
}
