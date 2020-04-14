/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// A delegate to respond to bluetooth discovery callbacks
protocol BluetoothDiscoveryDelegate: class {
    /// The discovery service did discover some data and calculated the distance of the source
    /// - Parameters:
    ///   - data: The data received
    ///   - TXPowerlevel: The TX Power level of both connection devices
    ///   - RSSI: The RSSI of both connection devices
    func didDiscover(data: Data, TXPowerlevel: Double?, RSSI: Double?) throws
}

/// A delegate that can react to bluetooth permission requests
protocol BluetoothPermissionDelegate: class {
    /// The Bluetooth device is turned off
    func deviceTurnedOff()
    /// The app is not authorized to use bluetooth
    func unauthorized()
}
