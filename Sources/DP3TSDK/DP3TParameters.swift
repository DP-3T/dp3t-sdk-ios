/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CoreBluetooth
import Foundation

public struct DP3TParameters: Codable {
    static let parameterVersion: Int = 5

    let version: Int

    init() {
        version = DP3TParameters.parameterVersion
    }

    public var crypto = Crypto()

    public var networking = Networking()

    public var contactMatching = ContactMatching()

    public struct Crypto: Codable {
        public var keyLength: Int = 16

        public var numberOfDaysToKeepData: Int = 21

        public var timeZone: TimeZone = TimeZone(identifier: "UTC")!

        public var numberOfDaysToKeepMatchedContacts = 10

        public var numberOfKeysToSubmit: Int = 14
    }

    public struct Networking: Codable {
        /// allowed client time inconsistency
        public var timeShiftThreshold: TimeInterval = 30 * .second
        // 2 Hour batches
        public var batchLength: TimeInterval = .day

        public var timeDeltaToEnsureBackendIsReady = 2 * .minute
    }

    public struct ContactMatching: Codable {
        public var contactAttenuationThreshold: Double = 73.0

        public var numberOfWindowsForExposure: Int = 3

        public var windowDuration: TimeInterval = .minute * 5
    }
}
