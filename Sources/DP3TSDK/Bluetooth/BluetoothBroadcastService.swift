/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CoreBluetooth
import Foundation
import UIKit

/// A service to broadcast bluetooth packets containing the DP3T token
class BluetoothBroadcastService: NSObject {
    /// The peripheral manager
    private var peripheralManager: CBPeripheralManager?
    /// The broadcasted service
    private var service: CBMutableService?

    /// The DP3T crypto algorithm
    private weak var crypto: DP3TCryptoModule?

    /// Random device name for enhanced privacy
    private var localName: String = UUID().uuidString

    /// An object that can handle bluetooth permission requests and errors
    public weak var permissionDelegate: BluetoothPermissionDelegate?

    #if CALIBRATION
        /// A logger to output messages
        public weak var logger: LoggingDelegate?
    #endif

    /// Create a Bluetooth broadcaster with a DP3T crypto algorithm
    /// - Parameter crypto: The DP3T crypto algorithm
    public init(crypto: DP3TCryptoModule) {
        self.crypto = crypto
        super.init()
    }

    /// Start the broadcast service
    public func startService() {
        guard peripheralManager == nil else {
            #if CALIBRATION
                logger?.log(type: .sender, "startService service already started")
            #endif
            return
        }
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [
            CBPeripheralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
            CBPeripheralManagerOptionRestoreIdentifierKey: "DP3TTracingPeripheralManagerIdentifier",
        ])
    }

    /// Stops the broadcast service
    public func stopService() {
        #if CALIBRATION
            logger?.log(type: .sender, "stopping Services")
        #endif

        peripheralManager?.removeAllServices()
        peripheralManager?.stopAdvertising()
        service = nil
        peripheralManager = nil
    }

    /// Adds a bluetooth service and broadcast it
    private func addService() {
        guard peripheralManager?.state == .some(.poweredOn) else {
            return
        }
        service = CBMutableService(type: BluetoothConstants.serviceCBUUID,
                                   primary: true)
        let characteristic = CBMutableCharacteristic(type: BluetoothConstants.characteristicsCBUUID,
                                                     properties: [.read, .notify],
                                                     value: nil,
                                                     permissions: .readable)
        service?.characteristics = [characteristic]
        peripheralManager?.add(service!)

        #if CALIBRATION
            logger?.log(type: .sender, "added Service with \(BluetoothConstants.serviceCBUUID.uuidString)")
        #endif
    }
}

// MARK: CBPeripheralManagerDelegate implementation

extension BluetoothBroadcastService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        #if CALIBRATION
            logger?.log(type: .sender, state: peripheral.state, prefix: "peripheralManagerDidUpdateState")
        #endif

        switch peripheral.state {
        case .poweredOn where service == nil:
            addService()
        case .poweredOff:
            permissionDelegate?.deviceTurnedOff()
        case .unauthorized:
            permissionDelegate?.unauthorized()
        default:
            break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error _: Error?) {
        #if CALIBRATION
            logger?.log(type: .sender, state: peripheral.state, prefix: "peripheralManagerdidAddservice")
        #endif

        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BluetoothConstants.serviceCBUUID],
            CBAdvertisementDataLocalNameKey: "",
        ])
    }

    #if CALIBRATION
        func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
            logger?.log(type: .sender, state: peripheral.state, prefix: "peripheralManagerDidStartAdvertising")
            if let error = error {
                logger?.log(type: .sender, "peripheralManagerDidStartAdvertising error: \(error.localizedDescription)")
            }
        }
    #endif

    func peripheralManager(_: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        #if CALIBRATION
            logger?.log(type: .sender, "didReceiveRead")
        #endif
        do {
            let data = try crypto!.getCurrentEphID()

            switch DP3TMode.current {
            #if CALIBRATION
                case let .calibration(identifierPrefix) where identifierPrefix != "":
                    request.value = identifierPrefix.data(using: .utf8)! + data.prefix(22)
            #endif
            default:
                request.value = data
            }

            peripheralManager?.respond(to: request, withResult: .success)
            #if CALIBRATION
                logger?.log(type: .sender, "← ✅ didReceiveRead: Responded with new token: \(data.hexEncodedString)")
            #endif
        } catch {
            peripheralManager?.respond(to: request, withResult: .unlikelyError)
            #if CALIBRATION
                logger?.log(type: .sender, "← ❌ didReceiveRead: Could not respond because token was not generated \(error)")
            #endif
        }
    }

    func peripheralManager(_: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        if let services: [CBMutableService] = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService],
            let service = services.first(where: { $0.uuid == BluetoothConstants.serviceCBUUID }) {
            self.service = service
            #if CALIBRATION
                logger?.log(type: .sender, "PeripheralManager#willRestoreState services :\(services.count)")
            #endif
        }
    }
}
