/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation
import CoreBluetooth


public struct DP3TParameters: Codable {

    static let parameterVersion: Int = 3

    let version: Int

    init() {
        version = DP3TParameters.parameterVersion
    }

    public var bluetooth = Bluetooth()

    public var crypto = Crypto()

    public var networking = Networking()

    public var contactMatching = ContactMatching()

    public struct Bluetooth: Codable {
        /// DP-3T Bluetooth UUID
        public var serviceUUID = "FD68"

        var serviceCBUUID: CBUUID {
            get {
                CBUUID(string: serviceUUID)
            }
            set {
                serviceUUID = newValue.uuidString
            }
        }

        /// Predefined Characteristics CBUUID
        public var characteristicsUUID = "8c8494e3-bab5-1848-40a0-1b06991c0001"

        var characteristicsCBUUID: CBUUID {
            get {
                CBUUID(string: characteristicsUUID)
            }
            set {
                characteristicsUUID = newValue.uuidString
            }
        }

        /// The delay after what we reconnect to a device
        public var peripheralReconnectDelay: Int = Int(TimeInterval.minute)

        /// If we weren't able to connect to a peripheral since x seconds we dont keep track of it
        /// This is needed because peripheralId's are roatating
        public var peripheralDisposeInterval: TimeInterval = 30 * .minute
        public var peripheralDisposeIntervalSinceDiscovery: TimeInterval = 30 * .minute

        public var peripheralStateRestorationDiscoveryOffset: TimeInterval = 15 * .minute

        /// how many rssi value should be read if we connect to a device
        public var rssiValueRequirement: Int = 3
    }

    public struct Crypto: Codable {

        public var keyLength: Int = 16

        public var numberOfDaysToKeepData: Int = 21

        public var numberOfEpochsPerDay: Int = 24 * 4

        public var secondsPerEpoch: TimeInterval = .day / Double(24 * 4)

        public var broadcastKey: Data = "broadcast key".data(using: .utf8)!

        public var timeZone: TimeZone = TimeZone(identifier: "UTC")!

        public var contactsThreshold: Int = 1

        public var numberOfDaysToKeepMatchedContacts = 10

    }

    public struct Networking: Codable {
        /// allowed client time inconsistency
        public var timeShiftThreshold: TimeInterval = 30 * .second
        // 2 Hour batches
        public var batchLength: TimeInterval = TimeInterval.day / 12.0
    }

    public struct ContactMatching: Codable {
        public var defaultTxPowerLevel: Double = 12.0

        public var contactAttenuationThreshold: Double = 73.0

        public var numberOfWindowsForExposure: Int = 15

        public var windowDuration: TimeInterval = .minute
    }
}
