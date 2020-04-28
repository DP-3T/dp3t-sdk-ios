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
    private let appInfo: DP3TApplicationInfo

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

    /// the urlSession to use for networking
    private let urlSession: URLSession

    /// The background task manager. This is marked as Any? because it is only available as of iOS 13 and properties cannot be
    /// marked with @available without causing the whole class to be restricted also.
    private let backgroundTaskManager: Any?

    /// delegate
    public weak var delegate: DP3TTracingDelegate?

    #if CALIBRATION
        /// getter for identifier prefix for calibration mode
        private(set) var identifierPrefix: String {
            get {
                switch DP3TMode.current {
                case let .calibration(identifierPrefix, _):
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
            switch state.infectionStatus {
            case .infected:
                Default.shared.didMarkAsInfected = true
            default:
                Default.shared.didMarkAsInfected = false
            }
            Default.shared.lastSync = state.lastSync
            DispatchQueue.main.async {
                self.delegate?.DP3TTracingStateChanged(self.state)
            }
        }
    }

    /// Initializer
    /// - Parameters:
    ///   - appInfo: applicationInfot to use (either discovery or manually initialized)
    ///   - urlSession: the url session to use for networking (app can set it to enable certificate pinning)
    init(appInfo: DP3TApplicationInfo, urlSession: URLSession) throws {
        self.appInfo = appInfo
        self.urlSession = urlSession
        database = try DP3TDatabase()
        crypto = try DP3TCryptoModule()
        matcher = try DP3TMatcher(database: database, crypto: crypto)
        synchronizer = KnownCasesSynchronizer(appInfo: appInfo, database: database, matcher: matcher)
        applicationSynchronizer = ApplicationSynchronizer(appInfo: appInfo, storage: database.applicationStorage, urlSession: urlSession)
        broadcaster = BluetoothBroadcastService(crypto: crypto)
        discoverer = BluetoothDiscoveryService()
        state = TracingState(numberOfHandshakes: (try? database.handshakesStorage.count()) ?? 0,
                             numberOfContacts: (try? database.contactsStorage.count()) ?? 0,
                             trackingState: .stopped,
                             lastSync: Default.shared.lastSync,
                             infectionStatus: InfectionStatus.getInfectionState(with: database),
                             backgroundRefreshState: UIApplication.shared.backgroundRefreshStatus)

        KnownCasesSynchronizer.initializeSynchronizerIfNeeded()

        if #available(iOS 13.0, *) {
            let backgroundTaskManager = DP3TBackgroundTaskManager()
            self.backgroundTaskManager = backgroundTaskManager
            #if CALIBRATION
                backgroundTaskManager.logger = self
            #endif
            backgroundTaskManager.register()
        } else {
            backgroundTaskManager = nil
        }

        broadcaster.permissionDelegate = self
        discoverer.permissionDelegate = self
        discoverer.delegate = matcher
        matcher.delegate = self

        #if CALIBRATION
            broadcaster.logger = self
            discoverer.logger = self
            database.logger = self
            crypto.debugSecretKeysStorageDelegate = database.secretKeysStorage
        #endif

        NotificationCenter.default.addObserver(self, selector: #selector(backgroundRefreshStatusDidChange), name: UIApplication.backgroundRefreshStatusDidChangeNotification, object: nil)
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
    func sync(callback: ((Result<Void, DP3TTracingError>) -> Void)?) {
        try? database.generateContactsFromHandshakes()
        try? state.numberOfContacts = database.contactsStorage.count()
        try? state.numberOfHandshakes = database.handshakesStorage.count()
        getATracingServiceClient(forceRefresh: true) { [weak self] result in
            switch result {
            case let .failure(error):
                callback?(.failure(error))
                return
            case let .success(service):
                self?.synchronizer.sync(service: service) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            self?.state.lastSync = Date()
                            callback?(.success(()))
                        case let .failure(error):
                            callback?(.failure(.networkingError(error: error)))
                        }
                    }
                }
            }
        }
    }

    /// get the current status of the SDK
    /// - Parameter callback: callback
    func status(callback: (Result<TracingState, DP3TTracingError>) -> Void) {
        try? state.numberOfHandshakes = database.handshakesStorage.count()
        try? state.numberOfContacts = database.contactsStorage.count()
        callback(.success(state))
    }

    /// tell the SDK that the user was exposed
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authString: Authentication string for the exposure change
    ///   - callback: callback
    ///   - isFakeRequest: indicates if the request should be a fake one. This method should be called regulary so people sniffing the networking traffic can no figure out if somebody is marking themself actually as exposed
    func iWasExposed(onset: Date,
                     authentication: ExposeeAuthMethod,
                     callback: @escaping (Result<Void, DP3TTracingError>) -> Void,
                     isFakeRequest: Bool = false) {
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
                    var day: DayDate
                    var key: Data

                    if isFakeRequest {
                        //Send random data if request is fake
                        day = DayDate()
                        key = (try? Crypto.generateRandomKey()) ?? Data()
                    } else {
                        (day, key) = try self.crypto.getSecretKeyForPublishing(onsetDate: onset)
                    }

                    let authData: String?
                    if case let ExposeeAuthMethod.JSONPayload(token: token) = authentication {
                        authData = token
                    } else {
                        authData = nil
                    }
                    let model = ExposeeModel(key: key, onset: day, authData: authData, fake: isFakeRequest)
                    service.addExposee(model, authentication: authentication) { [weak self] result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                if !isFakeRequest {
                                    self?.state.infectionStatus = .infected
                                }
                                callback(.success(()))
                            case let .failure(error):
                                callback(.failure(.networkingError(error: error)))
                            }
                        }
                    }
                } catch let error as DP3TTracingError {
                    DispatchQueue.main.async {
                        callback(.failure(error))
                    }
                } catch {
                    DispatchQueue.main.async {
                        callback(.failure(DP3TTracingError.cryptographyError(error: "Cannot get secret key")))
                    }
                }
            }
        }
    }

    #if CALIBRATION
        func getSecretKeyRepresentationForToday() throws -> String {
            let key = try crypto.getCurrentSK()
            let keyRepresentation = key.base64EncodedString()
            return "****** ****** " + String(keyRepresentation.suffix(6))
        }
    #endif

    /// used to construct a new tracing service client
    private func getATracingServiceClient(forceRefresh: Bool, callback: @escaping (Result<ExposeeServiceClient, DP3TTracingError>) -> Void) {
        if forceRefresh == false, let cachedTracingServiceClient = cachedTracingServiceClient {
            callback(.success(cachedTracingServiceClient))
            return
        }

        switch appInfo {
        case let .discovery(appId, _):
            do {
                try applicationSynchronizer.sync { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        do {
                            let desc = try self.database.applicationStorage.descriptor(for: appId)
                            let client = ExposeeServiceClient(descriptor: desc)
                            self.cachedTracingServiceClient = client
                            callback(.success(client))
                        } catch {
                            callback(.failure(DP3TTracingError.databaseError(error: error)))
                        }
                    case let .failure(error):
                        callback(.failure(error))
                    }
                }
            } catch {
                callback(.failure(DP3TTracingError.databaseError(error: error)))
            }
        case let .manual(appInfo):
            let client = ExposeeServiceClient(descriptor: appInfo, urlSession: urlSession)
            callback(.success(client))
        }
    }

    /// reset the SDK
    func reset() throws {
        stopTracing()
        Default.shared.lastLoadedBatchReleaseTime = nil
        Default.shared.lastSync = nil
        Default.shared.didMarkAsInfected = false
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

    @objc func backgroundRefreshStatusDidChange() {
        state.backgroundRefreshState = UIApplication.shared.backgroundRefreshStatus
    }
}

// MARK: DP3TMatcherDelegate implementation

extension DP3TSDK: DP3TMatcherDelegate {
    func didFindMatch() {
        state.infectionStatus = InfectionStatus.getInfectionState(with: database)
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
    func noIssues() {
        state.trackingState = .active
    }

    func deviceTurnedOff() {
        state.trackingState = .inactive(error: .bluetoothTurnedOff)
    }

    func unauthorized() {
        state.trackingState = .inactive(error: .permissonError)
    }
}

#if CALIBRATION
    extension DP3TSDK: LoggingDelegate {
        func log(type: LogType, _ string: String) {
            let appVersion: String
            switch DP3TMode.current {
            case .production:
                appVersion = "-"
            case let .calibration(_, av):
                appVersion = av
            }

            let logString = "[\(appVersion)|\(DP3TTracing.frameworkVersion)] \(type.description): \(string)"
            os_log("%@", logString)

            let dbLogString = "[\(appVersion)|\(DP3TTracing.frameworkVersion)] \(string)"
            if let entry = try? database.loggingStorage.log(type: type, message: dbLogString) {
                DispatchQueue.main.async {
                    self.delegate?.didAddLog(entry)
                }
            }
        }
    }
#endif
