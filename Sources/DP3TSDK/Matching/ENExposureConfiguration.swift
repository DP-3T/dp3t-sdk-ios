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
import DP3TSDK

extension ENExposureConfiguration {
    static var configuration: ENExposureConfiguration {
        let parameters = DP3TTracing.parameters.contactMatching

        let config = ENExposureConfiguration()
        config.attenuationDurationThresholds = [parameters.lowerThreshold as NSNumber,
                                                parameters.higherThreshold as NSNumber]
        config.reportTypeNoneMap = .confirmedTest
        config.metadata = ["attenuationDurationThresholds": [parameters.lowerThreshold,
                                                             parameters.higherThreshold]]
        config.infectiousnessForDaysSinceOnsetOfSymptoms = [:]
        for day in -14...14 {
            config.infectiousnessForDaysSinceOnsetOfSymptoms?[day as NSNumber] = ENInfectiousness.high.rawValue as NSNumber
        }
        return config

    }
}
