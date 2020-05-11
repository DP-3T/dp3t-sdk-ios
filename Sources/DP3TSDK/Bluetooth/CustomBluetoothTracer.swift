/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

class CustomBluetoothTracer: Tracer {
    weak var delegate: TracerDelegate?

    /// A service to broadcast bluetooth packets containing the DP3T token
    private let broadcaster: BluetoothBroadcastService

    /// The discovery service responsible of scanning for nearby bluetooth devices offering the DP3T service
    private let discoverer: BluetoothDiscoveryService

    /// The DP3T crypto algorithm
    private let crypto: DP3TCryptoModule

    private let database: DP3TDatabase

    #if CALIBRATION
        /// A logger to output messages
        func setLogger(logger: LoggingDelegate) {
            broadcaster.logger = logger
            discoverer.logger = logger
        }
    #endif

    private(set) var state: TrackingState = .stopped {
        didSet {
            delegate?.stateDidChange()
        }
    }

    init(database: DP3TDatabase, crypto: DP3TCryptoModule) throws {
        self.database = database
        self.crypto = crypto
        broadcaster = BluetoothBroadcastService(crypto: crypto)
        discoverer = BluetoothDiscoveryService()

        broadcaster.bluetoothDelegate = self
        discoverer.bluetoothDelegate = self
        discoverer.delegate = self
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            broadcaster.startService()
            discoverer.startScanning()
            state = .active
        } else {
            broadcaster.stopService()
            discoverer.stopScanning()
            state = .stopped
        }
    }

    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping ([SecretKey]?) -> Void) {
        do {
            let (day, key) = try crypto.getSecretKeyForPublishing(onsetDate: onsetDate)
            completionHandler([SecretKey(day: day, keyData: key)])
        } catch {
            completionHandler(nil)
        }
    }

    func resetAllData() {
        broadcaster.stopService()
        discoverer.stopScanning()
        crypto.reset()
    }
}

extension CustomBluetoothTracer: BluetoothDelegate {
    func noIssues() {
        state = .active
    }

    func deviceTurnedOff() {
        state = .inactive(error: .bluetoothTurnedOff)
    }

    func unauthorized() {
        state = .inactive(error: .permissonError)
    }

    func errorOccured(error: DP3TTracingError) {
        state = .inactive(error: error)
    }
}

extension CustomBluetoothTracer: BluetoothDiscoveryDelegate {
    func didDiscover(data: Data, TXPowerlevel: Double?, RSSI: Double, timestamp: Date) throws {
        let handshake = HandshakeModel(timestamp: timestamp,
                                       ephID: data,
                                       TXPowerlevel: TXPowerlevel,
                                       RSSI: RSSI)
        try database.handshakesStorage.add(handshake: handshake)
    }
}
