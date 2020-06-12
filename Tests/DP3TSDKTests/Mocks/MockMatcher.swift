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

class MockMatcher: Matcher {
    var timingManager: ExposureDetectionTimingManager?

    var delegate: MatcherDelegate?

    var error: Error?

    var timesCalledReceivedNewData: Int = 0

    func receivedNewData(_ data: Data, keyDate: Date, now: Date) throws {
        timesCalledReceivedNewData += 1
        timingManager?.addDetection(timestamp: now)
        if let error = error {
            throw error
        }
    }
}
