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
    public weak var bluetoothDelegate: BluetoothDelegate?

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
        service = CBMutableService(type: Default.shared.parameters.bluetooth.serviceCBUUID, primary: true)
        
        /// make sure creation of the service actually worked and log during calibration if not, otherwise force-unwrapping service will crash the app
        if let service = service {
            let characteristic = CBMutableCharacteristic(type: Default.shared.parameters.bluetooth.characteristicsCBUUID,
                                                         properties: [.read, .notify],
                                                         value: nil,
                                                         permissions: .readable)
            service.characteristics = [characteristic]
            peripheralManager?.add(service)

            #if CALIBRATION
                logger?.log(type: .sender, "added Service with \(Default.shared.parameters.bluetooth.serviceCBUUID.uuidString)")
            #endif
        } else {
            /// tell our delegate something went wrong
            bluetoothDelegate?.errorOccured(error: .bluetoothServiceFailed)
            #if CALIBRATION
                logger?.log(type: .sender, "❌ adding Service with \(Default.shared.parameters.bluetooth.serviceCBUUID.uuidString) FAILED")
            #endif
        }
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
            bluetoothDelegate?.noIssues()
            addService()
        case .poweredOff:
            bluetoothDelegate?.deviceTurnedOff()
        case .unauthorized:
            bluetoothDelegate?.unauthorized()
        default:
            break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            #if CALIBRATION
                logger?.log(type: .sender, "peripheralManagerdidAddservice error: \(error.localizedDescription)")
            #endif
            bluetoothDelegate?.errorOccured(error: .coreBluetoothError(error: error))
        }
        #if CALIBRATION
            logger?.log(type: .sender, state: peripheral.state, prefix: "peripheralManagerdidAddservice")
        #endif

        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Default.shared.parameters.bluetooth.serviceCBUUID],
            CBAdvertisementDataLocalNameKey: "",
        ])
    }


    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        #if CALIBRATION
            logger?.log(type: .sender, state: peripheral.state, prefix: "peripheralManagerDidStartAdvertising")
        #endif
        if let error = error {
            #if CALIBRATION
                logger?.log(type: .sender, "peripheralManagerDidStartAdvertising error: \(error.localizedDescription)")
            #endif
            bluetoothDelegate?.errorOccured(error: .coreBluetoothError(error: error))
        }
    }

    func peripheralManager(_: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        #if CALIBRATION
            logger?.log(type: .sender, "didReceiveRead")
        #endif
        do {
            guard let data = try crypto?.getCurrentEphID() else {
                throw DP3TTracingError.cryptographyError(error: "Tracing error: crypto not initialized?")
            }

            #if CALIBRATION
                if case let .calibration(identifierPrefix, _) = DP3TMode.current, identifierPrefix != "" {
                    let paddedIdentifier = identifierPrefix.padding(toLength: 4, withPad: " ", startingAt: 0)
                    let identifierData = paddedIdentifier.data(using: .utf8)!
                    data = identifierData + data.suffix(data.count - identifierData.count)
                }
            #endif

            request.value = data

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
            let service = services.first(where: { $0.uuid == Default.shared.parameters.bluetooth.serviceCBUUID }) {
            self.service = service
            #if CALIBRATION
                logger?.log(type: .sender, "PeripheralManager#willRestoreState services :\(services.count)")
            #endif
        }
    }
}
