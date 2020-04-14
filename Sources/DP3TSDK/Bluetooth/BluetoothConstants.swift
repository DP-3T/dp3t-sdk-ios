/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CoreBluetooth
import Foundation

/// Some constats used for configuring the bluetooth services
enum BluetoothConstants {
    /// Predefined Service CBUUID
    static var serviceCBUUID = CBUUID(string: "8c8494e3-bab5-1848-40a0-1b06991c0000")

    /// Predefined Characteristics CBUUID
    static var characteristicsCBUUID = CBUUID(string: "8c8494e3-bab5-1848-40a0-1b06991c0001")

    /// The delay after what we reconnect to a device
    static var peripheralReconnectDelay: Int = 60 * 5

    /// If we weren't able to connect to a peripheral since x seconds we dont keep track of it
    /// This is needed because peripheralId's are roatating
    static var peripheralDisposeInterval: TimeInterval = 60 * 60
    static var peripheralDisposeIntervalSinceDiscovery: TimeInterval = 10 * 60

    static var androidManufacturerId: UInt16 = 0xABBA
}
