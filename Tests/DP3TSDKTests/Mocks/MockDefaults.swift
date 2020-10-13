/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

@testable import DP3TSDK
import Foundation

class MockDefaults: DefaultStorage {
    var lastPublishedKeyTag: Int64?

    var exposureDetectionDates: [Date] = []

    var parameters: DP3TParameters = .init()

    var isFirstLaunch: Bool = false

    var lastSync: Date?

    var didMarkAsInfected: Bool = false

    func reset() {
        exposureDetectionDates = []
        lastPublishedKeyTag = nil
        parameters = .init()
        isFirstLaunch = false
        lastSync = nil
        didMarkAsInfected = false
    }
}
