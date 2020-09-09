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


extension Array where Element: ENExposureWindow {

    /// Groups windows by Date
    var groupByDay: [Date: [ENExposureWindow]] {
        reduce(into: [Date: [ENExposureWindow]]()) { result, window in
            result[window.date, default: []].append(window)
        }
    }

}

struct AttenuationValues {
    let lowerBucket: Int
    let higherBucket: Int
}

extension AttenuationValues {

    func matches(factorLow: Double, factorHigh: Double, triggerThreshold: Int) -> Bool {
        let computedThreshold: Double = (Double(lowerBucket) * factorLow + Double(higherBucket) * factorHigh)
        return computedThreshold > Double(triggerThreshold)
    }

}

extension Array where Element == ENExposureWindow {

    func getSeconds(above: Int = 0, below: Int) -> Int {
        reduce(into: 0) { (result, window) in
            result += window.scanInstances.reduce(into: 0) { (result, scanInstance) in
                if scanInstance.typicalAttenuation >= above, scanInstance.typicalAttenuation < below {
                    result += scanInstance.secondsSinceLastScan
                }
            }
        }
    }

    func attenuationValues(lowerThreshold: Int, higherThreshold: Int) -> AttenuationValues {
        return AttenuationValues(lowerBucket:  getSeconds(above: 0,              below: lowerThreshold),
                                 higherBucket: getSeconds(above: lowerThreshold, below: higherThreshold))
    }

}
