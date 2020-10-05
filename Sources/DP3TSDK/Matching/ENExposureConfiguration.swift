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

extension ENExposureConfiguration {
    static var configuration: ENExposureConfiguration {
        let config = ENExposureConfiguration()
        config.minimumRiskScore = 0
        config.attenuationDurationThresholds = [50, 70]
        config.attenuationLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        config.daysSinceLastExposureLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        config.durationLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        config.transmissionRiskLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        config.reportTypeNoneMap = .confirmedTest
        config.infectiousnessForDaysSinceOnsetOfSymptoms = [:]
        for day in -14...14 {
            config.infectiousnessForDaysSinceOnsetOfSymptoms?[day as NSNumber] = ENInfectiousness.high.rawValue as NSNumber
        }
        return config
    }
}
