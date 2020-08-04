/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import CoreBluetooth
import Foundation

public struct DP3TParameters: Codable {
    static let parameterVersion: Int = 13

    let version: Int

    init() {
        version = DP3TParameters.parameterVersion
    }

    public var crypto = Crypto()

    public var networking = Networking()

    public var contactMatching = ContactMatching()

    public struct Crypto: Codable {
        public var keyLength: Int = 16

        public var timeZone: TimeZone = TimeZone(identifier: "UTC")!

        public var numberOfDaysToKeepMatchedContacts = 10

        public var numberOfKeysToSubmit: Int = 30
    }

    public struct Networking: Codable {
        public var daysToCheck: Int = 10

        public var syncHourMorning: Int = 6

        public var syncHourEvening: Int = 18

        public var allowedServerTimeDiff: TimeInterval = .minute * 10
    }

    public struct ContactMatching: Codable {
        public var lowerThreshold: Int = 50

        public var higherThreshold: Int = 55

        public var factorLow: Double = 1.0

        public var factorHigh: Double = 0.5

        public var triggerThreshold: Int = 15
    }
}
