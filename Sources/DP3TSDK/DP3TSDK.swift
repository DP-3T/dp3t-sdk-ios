/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import os
import UIKit

#if canImport(ExposureNotification)
import ExposureNotification
#endif

/// Main class for handling SDK logic
class DP3TSDK {
    /// appId of this instance
    private let appInfo: DP3TApplicationInfo

    /// database probably also not needed with ExposureNotification Framework
    private let database: DP3TDatabase

    private var tracer: Tracer

    private let matcher: Matcher

    private let secretKeyProvider: SecretKeyProvider

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
                case let .customImplementationCalibration(identifierPrefix, _):
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
    init(appInfo: DP3TApplicationInfo, urlSession: URLSession, backgroundOperations: [Operation]) throws {
        self.appInfo = appInfo
        self.urlSession = urlSession
        database = try DP3TDatabase()

        switch DP3TMode.current {
        #if CALIBRATION
        case .customImplementationCalibration:
            fallthrough
        #endif
        case .customImplementation:
            let crypto = try DP3TCryptoModule()
            #if CALIBRATION
            crypto.debugSecretKeysStorageDelegate = database.secretKeysStorage
            #endif
            secretKeyProvider = crypto
            tracer = try CustomBluetoothTracer(database: database, crypto: crypto)
            matcher = try CustomImplementationMatcher(database: database, crypto: crypto)

        #if canImport(ExposureNotification)
        case .exposureNotificationFramework:
            if #available(iOS 13.5, *) {
                let manager = ENManager()
                tracer = ExposureNotificationTracer(manager: manager)
                matcher = ExposureNotificationMatcher(manager: manager, database: database)
                secretKeyProvider = manager
            } else {
                fatalError("ExposureNotification is only available from 13.5 upwards")
            }
        #endif
        }

        synchronizer = KnownCasesSynchronizer(appInfo: appInfo, database: database, matcher: matcher)

        applicationSynchronizer = ApplicationSynchronizer(appInfo: appInfo, storage: database.applicationStorage, urlSession: urlSession)

        state = TracingState(numberOfHandshakes: (try? database.handshakesStorage.count()) ?? 0,
                             numberOfContacts: (try? database.contactsStorage.count()) ?? 0,
                             trackingState: .stopped,
                             lastSync: Default.shared.lastSync,
                             infectionStatus: InfectionStatus.getInfectionState(from: database),
                             backgroundRefreshState: UIApplication.shared.backgroundRefreshStatus)

        KnownCasesSynchronizer.initializeSynchronizerIfNeeded()

        if #available(iOS 13.0, *) {
            let backgroundTaskManager = DP3TBackgroundTaskManager(operations: backgroundOperations)
            self.backgroundTaskManager = backgroundTaskManager
            #if CALIBRATION
                backgroundTaskManager.logger = self
            #endif
            backgroundTaskManager.register()
        } else {
            backgroundTaskManager = nil
        }


        #if CALIBRATION
            if let tracer = tracer as? CustomBluetoothTracer {
                tracer.setLogger(logger: self)
            }
            database.logger = self
        #endif

        tracer.delegate = self

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(backgroundRefreshStatusDidChange),
                                               name: UIApplication.backgroundRefreshStatusDidChangeNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.backgroundRefreshStatusDidChangeNotification,
                                                  object: nil)
    }

    /// start tracing
    func startTracing() throws {
        if case .infected = state.infectionStatus {
            throw DP3TTracingError.userAlreadyMarkedAsInfected
        }
        state.trackingState = .active
        tracer.setEnabled(true)
    }

    /// stop tracing
    func stopTracing() {
        tracer.setEnabled(false)
        state.trackingState = .stopped
    }

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
    /// This will stop tracing and reset the secret key
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authString: Authentication string for the exposure change
    ///   - isFakeRequest: indicates if the request should be a fake one. This method should be called regulary so people sniffing the networking traffic can no figure out if somebody is marking themself actually as exposed
    ///   - callback: callback
    func iWasExposed(onset: Date,
                     authentication: ExposeeAuthMethod,
                     isFakeRequest: Bool = false,
                     callback: @escaping (Result<Void, DP3TTracingError>) -> Void) {


        if !isFakeRequest,
            case .infected = state.infectionStatus {
            callback(.failure(DP3TTracingError.userAlreadyMarkedAsInfected))
        }

        let group = DispatchGroup()

        var secretKeyResult: Result<[SecretKey], DP3TTracingError> = .success([])

        if isFakeRequest {
            // Send random data if request is fake
            let day = DayDate(date: onset)
            let key = (try? Crypto.generateRandomKey()) ?? Data()
            secretKeyResult = .success([SecretKey(day: day, keyData: key)])
        } else {
            group.enter()
            secretKeyProvider.getDiagnosisKeys(onsetDate: onset) { (result) in
                secretKeyResult = result
                group.leave()
            }
        }
        group.notify(queue: .main) {
            switch secretKeyResult {
            case let .failure(error):
                callback(.failure(error))
            case let .success(keys):
                self.getATracingServiceClient(forceRefresh: false) { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    switch result {
                    case let .failure(error):
                        DispatchQueue.main.async {
                            callback(.failure(error))
                        }
                    case let .success(service):
                        let authData: String?
                        if case let ExposeeAuthMethod.JSONPayload(token: token) = authentication {
                            authData = token
                        } else {
                            authData = nil
                        }
                        // TODO: Send all keys when we have a new endpoint
                        // submit only first key for now
                        let key = keys.first!

                        let model = ExposeeModel(key: key.keyData, keyDate: key.day, authData: authData, fake: isFakeRequest)
                        service.addExposee(model, authentication: authentication) { [weak self] result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    if !isFakeRequest {
                                        self?.state.infectionStatus = .infected
                                        self?.stopTracing()
                                        try? self?.secretKeyProvider.reinitialize()
                                    }
                                    callback(.success(()))
                                case let .failure(error):
                                    callback(.failure(.networkingError(error: error)))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    #if CALIBRATION
        func getSecretKeyRepresentationForToday() throws -> String {
            guard let crypto = secretKeyProvider as? DP3TCryptoModule else { return "N/A" }
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
        secretKeyProvider.reset()
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

// MARK: BluetoothPermissionDelegate implementation

extension DP3TSDK: TracerDelegate {
    func stateDidChange() {
        state.trackingState = tracer.state
    }
}

#if CALIBRATION
    extension DP3TSDK: LoggingDelegate {
        func log(type: LogType, _ string: String) {
            let appVersion: String
            switch DP3TMode.current {
            case .customImplementation:
                appVersion = "-"
            case let .customImplementationCalibration(_, av):
                appVersion = av
            #if canImport(ExposureNotification)
            case .exposureNotificationFramework:
                appVersion = "-"
            #endif
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
