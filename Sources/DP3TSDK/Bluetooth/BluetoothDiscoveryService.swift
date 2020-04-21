/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CoreBluetooth
import Foundation
import UIKit.UIApplication

/// The discovery service responsible of scanning for nearby bluetooth devices offering the DP3T service
class BluetoothDiscoveryService: NSObject {
    /// The manager
    private var manager: CBCentralManager?

    /// A delegate for receiving the discovery callbacks
    public weak var delegate: BluetoothDiscoveryDelegate?

    /// A  delegate capable of responding to permission requests
    public weak var permissionDelegate: BluetoothPermissionDelegate?

    /// The storage for last connecting dates of peripherals
    private let storage: PeripheralStorage

    /// A logger for debugging
    #if CALIBRATION
        public weak var logger: LoggingDelegate?
    #endif

    /// A list of peripherals pending for retriving info
    private var pendingPeripherals: Set<CBPeripheral> = [] {
        didSet {
            if pendingPeripherals.isEmpty {
                endBackgroundTask()
            } else {
                beginBackgroundTask()
            }
            #if CALIBRATION
            logger?.log(type: .receiver, "updatedPeripherals: \n\(pendingPeripherals.map(\.debugDescription).joined(separator: "\n"))")
            #endif
        }
    }

    /// A list of peripherals that are about to be discarded
    private var peripheralsToDiscard: [CBPeripheral]?

    /// Transmission power levels per discovered peripheral
    private var powerLevelsCache: [UUID: Double] = [:]

    /// The computed distance from the discovered peripherals
    private var RSSICache: [UUID: Double] = [:]

    /// Identifier of the background task
    private var backgroundTask: UIBackgroundTaskIdentifier?

    /// Initialize the discovery object with a storage.
    /// - Parameters:
    ///   - storage: The storage.
    init(storage: PeripheralStorage) {
        self.storage = storage
        super.init()
    }

    /// Starts a background task
    private func beginBackgroundTask() {
        guard backgroundTask == nil else { return }
        #if CALIBRATION
            logger?.log(type: .receiver, "Starting Background Task")
        #endif
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "org.dpppt.bluetooth.backgroundtask") {
            self.endBackgroundTask()
            #if CALIBRATION
                self.logger?.log(type: .receiver, "Background Task ended")
            #endif
        }
    }

    /// Terminates a Backgroundtask if one is running
    private func endBackgroundTask() {
        guard let identifier = backgroundTask else { return }
        #if CALIBRATION
            logger?.log(type: .receiver, "Terminating background Task")
        #endif
        UIApplication.shared.endBackgroundTask(identifier)
        backgroundTask = nil
    }

    /// Update all services
    private func updateServices() {
        guard manager?.state == .some(.poweredOn) else { return }
        manager?.scanForPeripherals(withServices: [BluetoothConstants.serviceCBUUID], options: [
            CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
        ])
        #if CALIBRATION
            DispatchQueue.main.async {
                self.logger?.log(type: .receiver, " scanning for \(BluetoothConstants.serviceCBUUID.uuidString)")
            }
        #endif
    }

    /// Start the scanning service for nearby devices
    public func startScanning() {
        #if CALIBRATION
            logger?.log(type: .receiver, " start scanning")
        #endif
        if manager != nil {
            manager?.stopScan()
            manager?.scanForPeripherals(withServices: [BluetoothConstants.serviceCBUUID], options: [
                CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
            ])
            #if CALIBRATION
                logger?.log(type: .receiver, " scanning for \(BluetoothConstants.serviceCBUUID.uuidString)")
            #endif
        } else {
            manager = CBCentralManager(delegate: self, queue: nil, options: [
                CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
                CBCentralManagerOptionRestoreIdentifierKey: "DP3TTracingCentralManagerIdentifier",
            ])
        }
    }

    /// Stop scanning for nearby devices
    public func stopScanning() {
        #if CALIBRATION
            logger?.log(type: .receiver, "stop scanning")
            logger?.log(type: .receiver, "going to sleep with \(pendingPeripherals) peripherals")
        #endif
        manager?.stopScan()
        manager = nil
        pendingPeripherals.removeAll()
        endBackgroundTask()
    }
}

// MARK: CBCentralManagerDelegate implementation

extension BluetoothDiscoveryService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        #if CALIBRATION
            logger?.log(type: .receiver, state: central.state, prefix: "centralManagerDidUpdateState")
        #endif
        switch central.state {
        case .poweredOn:
            #if CALIBRATION
                logger?.log(type: .receiver, " scanning for \(BluetoothConstants.serviceCBUUID.uuidString)")
            #endif
            manager?.scanForPeripherals(withServices: [BluetoothConstants.serviceCBUUID], options: [
                CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
            ])
            peripheralsToDiscard?.forEach { peripheral in
                try? self.storage.discard(uuid: peripheral.identifier.uuidString)
                self.manager?.cancelPeripheralConnection(peripheral)
            }
            peripheralsToDiscard = nil
        case .poweredOff:
            permissionDelegate?.deviceTurnedOff()
        case .unauthorized:
            permissionDelegate?.unauthorized()
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        #if CALIBRATION
            logger?.log(type: .receiver, " didDiscover: \(peripheral), rssi: \(RSSI)db")
        #endif
        if let power = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double {
            #if CALIBRATION
                logger?.log(type: .receiver, " found TX-Power in Advertisment data: \(power)")
            #endif
            powerLevelsCache[peripheral.identifier] = power
        } else {
            #if CALIBRATION
                logger?.log(type: .receiver, " TX-Power not available")
            #endif
        }
        RSSICache[peripheral.identifier] = Double(truncating: RSSI)

        tidyUpPendingPeripherals()

        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let data: EphID = serviceData[BluetoothConstants.serviceCBUUID],
           data.count == CryptoConstants.keyLenght {

            let id = peripheral.identifier
            try? delegate?.didDiscover(data: data, TXPowerlevel: powerLevelsCache[id], RSSI: RSSICache[id])

            #if CALIBRATION
                logger?.log(type: .receiver, "Found service data \(data.hexEncodedString)")
                let identifier = String(data: data[..<4], encoding: .utf8) ?? "Unable to decode"
                logger?.log(type: .receiver, " → ✅ Received (EphID in Advertisement: \(identifier)) from \(peripheral.identifier) at \(Date())")
            #endif
        } else {
            // Only connect if we didn't got manufacturer data
            // we only get the manufacturer if iOS is actively scanning
            // otherwise we have to connect to the peripheral and read the characteristics
            try? storage.setDiscovery(uuid: peripheral.identifier)
            pendingPeripherals.insert(peripheral)
            connect(peripheral)
        }
    }

    func tidyUpPendingPeripherals(){
        // Tidy up pending peripherals (remove peripherals in "connecting" state if they are older than the threshold)
        peripheralsToDiscard = []
        try? storage.loopThrough(block: { (entity) -> Bool in
            var toDiscard: String?
            if let lastConnection = entity.lastConnection,
                Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                toDiscard = entity.uuid
            } else if Date().timeIntervalSince(entity.discoverTime) > BluetoothConstants.peripheralDisposeIntervalSinceDiscovery {
                toDiscard = entity.uuid
            }
            if let toDiscard = toDiscard,
                let peripheralToDiscard = pendingPeripherals.first(where: { $0.identifier.uuidString == toDiscard }) {
                peripheralsToDiscard?.append(peripheralToDiscard)
            }
            return true
        })

        if let toDiscard = peripheralsToDiscard, toDiscard.count > 0 {
            toDiscard.forEach {
                    manager?.cancelPeripheralConnection($0)
                    pendingPeripherals.remove($0)
                    try? storage.discard(uuid: $0.identifier.uuidString)
            }

            #if CALIBRATION
            logger?.log(type: .receiver, "tidyUpPendingPeripherals: Disposed \(toDiscard.count) peripherals")
            #endif
        }
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        #if CALIBRATION
            logger?.log(type: .receiver, " didConnect: \(peripheral)")
        #endif
        try? storage.setConnection(uuid: peripheral.identifier)
        tidyUpPendingPeripherals()
        peripheral.delegate = self
        peripheral.discoverServices([BluetoothConstants.serviceCBUUID])
        peripheral.readRSSI()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let entity = try? storage.get(uuid: peripheral.identifier),
            let lastConnection = entity.lastConnection {
            if Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                #if CALIBRATION
                    logger?.log(type: .receiver, " didDisconnectPeripheral dispose because last connection was \(Date().timeIntervalSince(lastConnection))seconds ago")
                #endif
                pendingPeripherals.remove(peripheral)
                try? storage.discard(uuid: peripheral.identifier.uuidString)
                return
            }
        }

        if let error = error {
            #if CALIBRATION
                logger?.log(type: .receiver, " didDisconnectPeripheral (unexpected): \(peripheral) with error: \(error)")
            #endif

            connect(peripheral)
        } else {
            #if CALIBRATION
                logger?.log(type: .receiver, " didDisconnectPeripheral (successful): \(peripheral)")
            #endif

            // Do not re-connect to the same peripheral right away again to save battery
            connect(peripheral, delayed: true)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        #if CALIBRATION
            logger?.log(type: .receiver, " didFailToConnect: \(peripheral)")
            logger?.log(type: .receiver, " didFailToConnect error: \(error.debugDescription)")
        #endif

        if let entity = try? storage.get(uuid: peripheral.identifier) {
            if let lastConnection = entity.lastConnection,
                Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                #if CALIBRATION
                    logger?.log(type: .receiver, " didFailToConnect dispose because last connection was \(Date().timeIntervalSince(lastConnection))seconds ago")
                #endif
                pendingPeripherals.remove(peripheral)
                try? storage.discard(uuid: peripheral.identifier.uuidString)
                return
            } else if Date().timeIntervalSince(entity.discoverTime) > BluetoothConstants.peripheralDisposeIntervalSinceDiscovery {
                #if CALIBRATION
                    logger?.log(type: .receiver, " didFailToConnect dispose because connection never suceeded and was \(Date().timeIntervalSince(entity.discoverTime))seconds ago")
                #endif
                pendingPeripherals.remove(peripheral)
                try? storage.discard(uuid: peripheral.identifier.uuidString)
                return
            }
        }

        connect(peripheral)
    }

    func connect(_ peripheral: CBPeripheral, delayed: Bool = false) {
        #if CALIBRATION
        logger?.log(type: .receiver, "reconnect to peripheral \(peripheral) \(delayed ?  "delayed" : "right away")")
        #endif
        var options: [String : Any]? = nil
        if delayed {
            options = [CBConnectPeripheralOptionStartDelayKey: NSNumber(integerLiteral: BluetoothConstants.peripheralReconnectDelay)]
        }
        manager?.connect(peripheral, options: options)
    }

    func centralManager(_: CBCentralManager, willRestoreState dict: [String: Any]) {
        #if CALIBRATION
            logger?.log(type: .receiver, " CentralManager#willRestoreState")
        #endif
        if let peripherals: [CBPeripheral] = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            peripheralsToDiscard = []

            try? storage.loopThrough(block: { (entity) -> Bool in
                var toDiscard: String?

                // discard peripheral from storage if it didn't got restored
                guard peripherals.contains(where: { $0.identifier.uuidString == entity.uuid }) else {
                    try? storage.discard(uuid: entity.uuid)
                    return true
                }

                if let lastConnection = entity.lastConnection,
                    Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                    toDiscard = entity.uuid
                } else if Date().timeIntervalSince(entity.discoverTime) > BluetoothConstants.peripheralDisposeIntervalSinceDiscovery {
                    toDiscard = entity.uuid
                }
                if let toDiscard = toDiscard,
                    let peripheralToDiscard = peripherals.first(where: { $0.identifier.uuidString == toDiscard }) {
                    peripheralsToDiscard?.append(peripheralToDiscard)
                }
                return true
            })

            peripherals
                .filter { !(peripheralsToDiscard?.contains($0) ?? false) }
                .forEach { pendingPeripherals.insert($0) }
            #if CALIBRATION
                logger?.log(type: .receiver, "CentralManager#willRestoreState restoring peripherals \(pendingPeripherals) discarded \(peripheralsToDiscard.debugDescription) \n")
            #endif
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error _: Error?) {
        RSSICache[peripheral.identifier] = Double(truncating: RSSI)
    }
}

extension BluetoothDiscoveryService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            #if CALIBRATION
                logger?.log(type: .receiver, " didDiscoverCharacteristicsFor" + error.localizedDescription)
            #endif
            return
        }
        let cbuuid = BluetoothConstants.characteristicsCBUUID
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == cbuuid }) else {
            return
        }
        peripheral.readValue(for: characteristic)
        #if CALIBRATION
            logger?.log(type: .receiver, " found characteristic \(peripheral.name.debugDescription)")
        #endif
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            #if CALIBRATION
                logger?.log(type: .receiver, " didUpdateValueFor " + error.localizedDescription)
            #endif
            manager?.cancelPeripheralConnection(peripheral)
            return
        }

        guard let data = characteristic.value else {
            #if CALIBRATION
                logger?.log(type: .receiver, " → ❌ Could not read data from characteristic of \(peripheral.identifier) at \(Date())")
            #endif
            manager?.cancelPeripheralConnection(peripheral)
            return
        }

        guard data.count == CryptoConstants.keyLenght else {
            #if CALIBRATION
                logger?.log(type: .receiver, " → ❌ Received wrong number of bytes (\(data.count) bytes) from \(peripheral.identifier) at \(Date())")
            #endif
            manager?.cancelPeripheralConnection(peripheral)
            return
        }
        #if CALIBRATION
            let identifier = String(data: data[0 ..< 4], encoding: .utf8) ?? "Unable to decode"
            logger?.log(type: .receiver, " → ✅ Received (identifier: \(identifier)) (\(data.count) bytes) from \(peripheral.identifier) at \(Date()): \(data.hexEncodedString)")
        #endif
        manager?.cancelPeripheralConnection(peripheral)

        let id = peripheral.identifier
        try? delegate?.didDiscover(data: data, TXPowerlevel: powerLevelsCache[id], RSSI: RSSICache[id])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        #if CALIBRATION
            logger?.log(type: .receiver, " didDiscoverServices for \(peripheral.identifier)")
        #endif
        if let error = error {
            #if CALIBRATION
                logger?.log(type: .receiver, error.localizedDescription)
            #endif
            return
        }
        if let service = peripheral.services?.first(where: { $0.uuid == BluetoothConstants.serviceCBUUID }) {
            peripheral.discoverCharacteristics([BluetoothConstants.characteristicsCBUUID], for: service)
        } else {
            #if CALIBRATION
            logger?.log(type: .receiver, " No service found found: -> (\(peripheral.services?.description ?? "none"))")
            #endif
            manager?.cancelPeripheralConnection(peripheral)
        }
    }
}

extension Data {
    var hexEncodedString: String {
        return map { String(format: "%02hhx ", $0) }.joined()
    }
}
