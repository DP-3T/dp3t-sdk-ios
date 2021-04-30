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
class MockWindow: ENExposureWindow {
    private var internalDate: Date
    private var internalScanInstances: [ENScanInstance]

    init(date: Date, scanInstances: [ENScanInstance]) {
        self.internalDate = date
        self.internalScanInstances = scanInstances
    }

    override var date: Date {
        get {
            internalDate
        }
        set {
            internalDate = newValue
        }
    }

    override var scanInstances: [ENScanInstance] {
        get {
            internalScanInstances
        }
        set {
            internalScanInstances = newValue
        }
    }
}
