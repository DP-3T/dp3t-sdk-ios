/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CoreBluetooth
import Foundation

public struct DP3TParameters: Codable {
    static let parameterVersion: Int = 10

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

        public var numberOfKeysToSubmit: Int = 14
    }

    public struct Networking: Codable {
        /// allowed client time inconsistency
        public var timeShiftThreshold: TimeInterval = 30 * .second

        public var daysToCheck: Int = 10

        public var timeDeltaToEnsureBackendIsReady = 2 * .minute

        public var syncHourMorning: Int = 6

        public var syncHourEvening: Int = 18
    }

    public struct ContactMatching: Codable {

        public var lowerThreshold: Int = 50

        public var higherThreshold: Int = 55

        public var factorLow: Double = 1.0

        public var factorHigh: Double = 0.5

        public var triggerThreshold: Int = 15
        
    }
}
