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
        config.reportTypeNoneMap = .confirmedTest
        config.infectiousnessForDaysSinceOnsetOfSymptoms = [ENDaysSinceOnsetOfSymptomsUnknown as NSNumber: ENInfectiousness.high.rawValue as NSNumber]
        for day in -14...14 {
            config.infectiousnessForDaysSinceOnsetOfSymptoms?[day as NSNumber] = ENInfectiousness.high.rawValue as NSNumber
        }
        return config
    }
}
