/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import os
import UIKit

/// Main class for handling SDK logic
class DP3TSDK {
    /// appId of this instance
    private let appId: String

    /// A service to broadcast bluetooth packets containing the DP3T token
    private let broadcaster: BluetoothBroadcastService

    /// The discovery service responsible of scanning for nearby bluetooth devices offering the DP3T service
    private let discoverer: BluetoothDiscoveryService

    /// matcher for DP3T tokens
    private let matcher: DP3TMatcher

    /// databsase
    private let database: DP3TDatabase

    /// The DP3T crypto algorithm
    private let crypto: DP3TCryptoModule

    /// Fetch the discovery data and stores it
    private let applicationSynchronizer: ApplicationSynchronizer

    /// Synchronizes data on known cases
    private let synchronizer: KnownCasesSynchronizer

    /// tracing service client
    private var cachedTracingServiceClient: ExposeeServiceClient?

    /// enviroemnt of this instance
    private let enviroment: Enviroment

    /// the urlSession to use for networking
    private let urlSession: URLSession

    /// delegate
    public weak var delegate: DP3TTracingDelegate?

    #if CALIBRATION
        /// getter for identifier prefix for calibration mode
        private(set) var identifierPrefix: String {
            get {
                switch DP3TMode.current {
                case let .calibration(identifierPrefix):
                    return identifierPrefix
                default:
                    fatalError("identifierPrefix is only usable in calibration mode")
                }
            }
            set {}
        }
    #endif

    /// keeps track of  SDK state
    private var state: TracingState {
        didSet {
            Default.shared.infectionStatus = state.infectionStatus
            Default.shared.lastSync = state.lastSync
            DispatchQueue.main.async {
                self.delegate?.DP3TTracingStateChanged(self.state)
            }
        }
    }

    /// Initializer
    /// - Parameters:
    ///   - appId: application identifer to use for discovery call
    ///   - enviroment: enviroment to use
    ///   - urlSession: the url session to use for networking (app can set it to enable certificate pinning)
    init(appId: String, enviroment: Enviroment, urlSession: URLSession) throws {
        self.enviroment = enviroment
        self.appId = appId
        self.urlSession = urlSession
        database = try DP3TDatabase()
        crypto = try DP3TCryptoModule()
        matcher = try DP3TMatcher(database: database, crypto: crypto)
        synchronizer = KnownCasesSynchronizer(appId: appId, database: database, matcher: matcher)
        applicationSynchronizer = ApplicationSynchronizer(enviroment: enviroment, storage: database.applicationStorage, urlSession: urlSession)
        broadcaster = BluetoothBroadcastService(crypto: crypto)
        discoverer = BluetoothDiscoveryService(storage: database.peripheralStorage)
        state = TracingState(numberOfHandshakes: (try? database.handshakesStorage.count()) ?? 0,
                             numberOfContacts: (try? database.contactsStorage.count()) ?? 0,
                             trackingState: .stopped,
                             lastSync: Default.shared.lastSync,
                             infectionStatus: Default.shared.infectionStatus)

        broadcaster.permissionDelegate = self
        discoverer.permissionDelegate = self
        discoverer.delegate = matcher
        matcher.delegate = self

        #if CALIBRATION
            broadcaster.logger = self
            discoverer.logger = self
            database.logger = self
        #endif

        print(database)

        try applicationSynchronizer.sync { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                if let desc = try? self.database.applicationStorage.descriptor(for: self.appId) {
                    let client = ExposeeServiceClient(descriptor: desc, urlSession: urlSession)
                    self.cachedTracingServiceClient = client
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    self.state.trackingState = .inactive(error: error)
                    self.stopTracing()
                }
            }
        }
    }

    /// start tracing
    func startTracing() throws {
        state.trackingState = .active
        discoverer.startScanning()
        broadcaster.startService()
    }

    /// stop tracing
    func stopTracing() {
        discoverer.stopScanning()
        broadcaster.stopService()
        state.trackingState = .stopped
    }

    #if CALIBRATION
        func startAdvertising() throws {
            state.trackingState = .activeAdvertising
            broadcaster.startService()
        }

        func startReceiving() throws {
            state.trackingState = .activeReceiving
            discoverer.startScanning()
        }
    #endif

    /// Perform a new sync
    /// - Parameter callback: callback
    /// - Throws: if a error happed
    func sync(callback: ((Result<Void, DP3TTracingErrors>) -> Void)?) throws {
        try database.generateContactsFromHandshakes()
        try? state.numberOfContacts = database.contactsStorage.count()
        try? state.numberOfHandshakes = database.handshakesStorage.count()
        getATracingServiceClient(forceRefresh: true) { [weak self] result in
            switch result {
            case let .failure(error):
                callback?(.failure(error))
                return
            case let .success(service):
                self?.synchronizer.sync(service: service) { [weak self] result in
                    if case .success = result {
                        self?.state.lastSync = Date()
                    }
                    callback?(result)
                }
            }
        }
    }

    /// get the current status of the SDK
    /// - Parameter callback: callback
    func status(callback: (Result<TracingState, DP3TTracingErrors>) -> Void) {
        try? state.numberOfHandshakes = database.handshakesStorage.count()
        try? state.numberOfContacts = database.contactsStorage.count()
        callback(.success(state))
    }

    /// tell the SDK that the user was exposed
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authString: Authentication string for the exposure change
    ///   - callback: callback
    func iWasExposed(onset: Date, authString: String, callback: @escaping (Result<Void, DP3TTracingErrors>) -> Void) {
        setExposed(onset: onset, authString: authString, callback: callback)
    }

    /// used to construct a new tracing service client
    private func getATracingServiceClient(forceRefresh: Bool, callback: @escaping (Result<ExposeeServiceClient, DP3TTracingErrors>) -> Void) {
        if forceRefresh == false, let cachedTracingServiceClient = cachedTracingServiceClient {
            callback(.success(cachedTracingServiceClient))
            return
        }
        try? applicationSynchronizer.sync { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                if let desc = try? self.database.applicationStorage.descriptor(for: self.appId) {
                    let client = ExposeeServiceClient(descriptor: desc)
                    self.cachedTracingServiceClient = client
                    callback(.success(client))
                } else {
                    callback(.failure(DP3TTracingErrors.CaseSynchronizationError))
                }
            case let .failure(error):
                callback(.failure(error))
            }
        }
    }

    /// update the backend with the new exposure state
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authString: Authentication string for the exposure change
    ///   - callback: callback
    private func setExposed(onset: Date, authString: String, callback: @escaping (Result<Void, DP3TTracingErrors>) -> Void) {
        getATracingServiceClient(forceRefresh: false) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case let .failure(error):
                DispatchQueue.main.async {
                    callback(.failure(error))
                }
            case let .success(service):
                do {
                    let block: ((Result<Void, DP3TTracingErrors>) -> Void) = { [weak self] result in
                        if case .success = result {
                            self?.state.infectionStatus = .infected
                        }
                        DispatchQueue.main.async {
                            callback(result)
                        }
                    }
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let key = try self.crypto.getSecretKeyForPublishing(onsetDate: onset) {
                        let model = ExposeeModel(key: key, onset: dateFormatter.string(from: onset), authData: ExposeeAuthData(value: authString))
                        service.addExposee(model, completion: block)
                    }
                } catch let error as DP3TTracingErrors {
                    DispatchQueue.main.async {
                        callback(.failure(error))
                    }
                } catch {
                    DispatchQueue.main.async {
                        callback(.failure(DP3TTracingErrors.CryptographyError(error: "Cannot get secret key")))
                    }
                }
            }
        }
    }

    /// reset the SDK
    func reset() throws {
        stopTracing()
        Default.shared.lastSync = nil
        Default.shared.infectionStatus = .healthy
        try database.emptyStorage()
        try database.destroyDatabase()
        crypto.reset()
        URLCache.shared.removeAllCachedResponses()
    }

    #if CALIBRATION
        func getHandshakes(request: HandshakeRequest) throws -> HandshakeResponse {
            try database.handshakesStorage.getHandshakes(request)
        }

        func numberOfHandshakes() throws -> Int {
            try database.handshakesStorage.numberOfHandshakes()
        }

        func getLogs(request: LogRequest) throws -> LogResponse {
            return try database.loggingStorage.getLogs(request)
        }
    #endif
}

// MARK: DP3TMatcherDelegate implementation

extension DP3TSDK: DP3TMatcherDelegate {
    func didFindMatch() {
        state.infectionStatus = .exposed
    }

    func handShakeAdded(_ handshake: HandshakeModel) {
        if let newHandshaked = try? database.handshakesStorage.count() {
            state.numberOfHandshakes = newHandshaked
        }
        #if CALIBRATION
            delegate?.didAddHandshake(handshake)
        #endif
    }
}

// MARK: BluetoothPermissionDelegate implementation

extension DP3TSDK: BluetoothPermissionDelegate {
    func deviceTurnedOff() {
        state.trackingState = .inactive(error: .BluetoothTurnedOff)
    }

    func unauthorized() {
        state.trackingState = .inactive(error: .PermissonError)
    }
}

#if CALIBRATION
    extension DP3TSDK: LoggingDelegate {
        func log(type: LogType, _ string: String) {
            os_log("%@: %@", type.description, string)
            if let entry = try? database.loggingStorage.log(type: type, message: string) {
                delegate?.didAddLog(entry)
            }
        }
    }
#endif
