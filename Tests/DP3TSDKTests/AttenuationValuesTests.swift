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
import XCTest


class AttenuationsValuesTests: XCTestCase {
    func testMatching() {
        let attenuationValues = AttenuationValues(lowerBucket: 120, higherBucket: 120)

        XCTAssert(attenuationValues.matches(factorLow: 0, factorHigh: 1, triggerThreshold: 2))
        XCTAssert(attenuationValues.matches(factorLow: 1, factorHigh: 0, triggerThreshold: 2))
        XCTAssertFalse(attenuationValues.matches(factorLow: 0, factorHigh: 0, triggerThreshold: 1))
        XCTAssertFalse(attenuationValues.matches(factorLow: 0, factorHigh: 0.5, triggerThreshold: 2))
        XCTAssertFalse(attenuationValues.matches(factorLow: 0.5, factorHigh: 0, triggerThreshold: 2))
    }

    func testRoundingMinutesUp(){
        let attenuationValues = AttenuationValues(lowerBucket: 59, higherBucket: 0)
        XCTAssert(attenuationValues.matches(factorLow: 1, factorHigh: 0, triggerThreshold: 1))
    }
}
