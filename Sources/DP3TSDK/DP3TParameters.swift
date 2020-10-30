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
    static let parameterVersion: Int = 16

    let version: Int

    init() {
        version = DP3TParameters.parameterVersion
    }

    public var crypto = Crypto()

    public var networking = Networking()

    public var contactMatching = ContactMatching()

    public struct Crypto: Codable {
        /// key length used to generate fake keys
        public var keyLength: Int = 16

        /// timeZone used for calculations (EN always uses UTC)
        public var timeZone: TimeZone = TimeZone(identifier: "UTC")!

        /// defines how many days matched exposures are stored
        public var numberOfDaysToKeepMatchedContacts = 14
    }

    public struct Networking: Codable {
        /// allowed time difference between server and device
        /// this is checked using HTTP Header 'date' and 'age'
        public var allowedServerTimeDiff: TimeInterval = .minute * 10

        /// max Age of keys retrieved from ExpsosureNotification SDK
        public var maxAgeOfKeyToRetreive: TimeInterval = .day * 14

        /// always fill up the keys submitted to the backend to this value
        public var numberOfKeysToSubmit: Int = 30
    }

    public struct ContactMatching: Codable {
        /// threshold for putting attenuation durations in the lower bucker
        public var lowerThreshold: Int = 55

        /// threshold for putting attenuation durations in the upper bucket
        public var higherThreshold: Int = 63

        /// factor for attenuation values in lower bucket
        public var factorLow: Double = 1.0

        /// factor for attenuation values in upper bucket
        public var factorHigh: Double = 0.5

        /// trigger threshold in minutes
        /// the equation lowerBucket * factorLow  + upperBucket * factorHigh > triggerThreshold has to be true in order for an epxosure to be counted
        public var triggerThreshold: Int = 15

        /// TimeInterval for which notifications should get generated after an exposure
        public var notificationGenerationTimeSpan: TimeInterval = .day * 10
    }
}
