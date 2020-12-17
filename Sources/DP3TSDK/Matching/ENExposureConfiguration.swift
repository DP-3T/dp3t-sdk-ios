/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import ExposureNotification

@available(iOS 12.5, *)
extension ENExposureConfiguration {
    /// This configuration only sets values needed to get ExposureWindows from the EN Framework
    /// DP3T does not use the risk calculation of the EN framework. It only uses ExposureWindows and ScanInstances to gather information about a exposures.
    static var configuration: ENExposureConfiguration {
        let config = ENExposureConfiguration()
        config.reportTypeNoneMap = .confirmedTest
        config.infectiousnessForDaysSinceOnsetOfSymptoms = [:]
        for day in -14...14 {
            config.infectiousnessForDaysSinceOnsetOfSymptoms?[day as NSNumber] = ENInfectiousness.high.rawValue as NSNumber
        }
        return config
    }
}
