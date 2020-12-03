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

/// object holding the lower and upper bucket (all values are in seconds)
struct AttenuationValues {
    let lowerBucket: Int
    let higherBucket: Int
    let disregarded: Int
}

extension AttenuationValues {
    /// Checks if the AttenuationValues match given the parameters, buckets are rounded up to the next minute.
    /// - Parameters:
    ///   - factorLow: the factor to multiply the lower bucket with (in seconds)
    ///   - factorHigh: the factor to multiply the upper bucket with (in seconds)
    ///   - triggerThreshold: the threshold which has to be reached in minutes
    /// - Returns: Boolean if matches the triggerThreshold
    func matches(factorLow: Double, factorHigh: Double, triggerThreshold: Int) -> Bool {
        let roundedMinutesLowerBucket = ceil(Double(lowerBucket) / TimeInterval.minute)
        let roundedMinutesHigherBucket = ceil(Double(higherBucket) / TimeInterval.minute)
        let computedThreshold: Double = (roundedMinutesLowerBucket * factorLow + roundedMinutesHigherBucket * factorHigh)
        return computedThreshold >= Double(triggerThreshold)
    }
}

extension Array where Element == ENExposureWindow {
    /// Get Seconds of ScanInstances with a typical attenuation between to given values
    /// - Parameters:
    ///   - above: typicalAttenuation greater than or equal to
    ///   - below: typicalAttenuation less than
    /// - Returns: the number of seconds
    func getSeconds(above: Int = 0, below: Int) -> Int {
        reduce(into: 0) { (result, window) in
            result += window.scanInstances.reduce(into: 0) { (result, scanInstance) in
                if scanInstance.typicalAttenuation >= above, scanInstance.typicalAttenuation < below {
                    result += scanInstance.secondsSinceLastScan
                }
            }
        }
    }

    /// Get an AttenuationValues object containing:
    ///     - seconds below the lower threshold
    ///     - seoncds between the lower threshold and higher threshold
    /// - Parameters:
    ///   - lowerThreshold: typicalAttenuation for lower bucket
    ///   - higherThreshold: typicalAttenuation for upper bucket
    /// - Returns: the 2 buckets
    func attenuationValues(lowerThreshold: Int, higherThreshold: Int) -> AttenuationValues {
        return AttenuationValues(lowerBucket:  getSeconds(above: 0,              below: lowerThreshold),
                                 higherBucket: getSeconds(above: lowerThreshold, below: higherThreshold),
                                 disregarded:  getSeconds(above: higherThreshold, below: Int.max))
    }
}
