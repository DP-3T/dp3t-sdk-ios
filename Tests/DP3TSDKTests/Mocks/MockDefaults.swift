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
    var firstExposureDetection: Date?

    var exposureDetectionDates: [Date] = []

    var lastSyncTimestamps: [Date: Date] = [:]

    var parameters: DP3TParameters = .init()

    var outstandingPublishes: Set<OutstandingPublish> = []

    var isFirstLaunch: Bool = false

    var lastSync: Date?

    var didMarkAsInfected: Bool = false
}
