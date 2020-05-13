/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import os
import UIKit
import ExposureNotification

/// Main class for handling SDK logic
@available(iOS 13.5, *)
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

    private let backgroundTaskManager: DP3TBackgroundTaskManager

    /// delegate
    public weak var delegate: DP3TTracingDelegate?

    private let log = Logger(DP3TDatabase.self, category: "DP3TSDK")

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
    init(appInfo: DP3TApplicationInfo, urlSession: URLSession, backgroundHandler: DP3TBackgroundHandler?) throws {
        self.appInfo = appInfo
        self.urlSession = urlSession
        database = try DP3TDatabase()

        let manager = ENManager()
        tracer = ExposureNotificationTracer(manager: manager)
        matcher = ExposureNotificationMatcher(manager: manager, database: database)
        secretKeyProvider = manager

        synchronizer = KnownCasesSynchronizer(appInfo: appInfo, matcher: matcher)

        applicationSynchronizer = ApplicationSynchronizer(appInfo: appInfo, storage: database.applicationStorage, urlSession: urlSession)

        backgroundTaskManager = DP3TBackgroundTaskManager(handler: backgroundHandler)

        state = TracingState(trackingState: .stopped,
                             lastSync: Default.shared.lastSync,
                             infectionStatus: InfectionStatus.getInfectionState(from: database),
                             backgroundRefreshState: UIApplication.shared.backgroundRefreshStatus)

        KnownCasesSynchronizer.initializeSynchronizerIfNeeded()
        backgroundTaskManager.register()

        tracer.delegate = self

        #if CALIBRATION
        Logger.delegate = database.loggingStorage
        #endif

        log.trace()

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
        log.trace()
        if case .infected = state.infectionStatus {
            throw DP3TTracingError.userAlreadyMarkedAsInfected
        }
        tracer.setEnabled(true)
    }

    /// stop tracing
    func stopTracing() {
        log.trace()
        tracer.setEnabled(false)
    }

    /// Perform a new sync
    /// - Parameter callback: callback
    /// - Throws: if a error happed
    func sync(callback: ((Result<Void, DP3TTracingError>) -> Void)?) {
        log.trace()
        if  ENManager.authorizationStatus != .authorized {
            log.error("cant run sync before being authorized")
            callback?(.failure(.permissonError))
            return
        }

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
        log.trace()
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
        log.trace()
        if !isFakeRequest,
            case .infected = state.infectionStatus {
            callback(.failure(DP3TTracingError.userAlreadyMarkedAsInfected))
        }

        let group = DispatchGroup()

        var secretKeyResult: Result<[CodableDiagnosisKey], DP3TTracingError> = .success([])

        if isFakeRequest {
            group.enter()
            secretKeyProvider.getFakeDiagnosisKeys { result in
                secretKeyResult = result
                group.leave()
            }
        } else {
            group.enter()
            secretKeyProvider.getDiagnosisKeys(onsetDate: onset) { result in
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

                        let completionHandler: (Result<Void, DP3TNetworkingError>) -> Void = { [weak self] result in
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
                        let model = ExposeeListModel(gaenKeys: keys, authData: authData, fake: isFakeRequest, delayedKeyDate: DayDate())
                        service.addExposeeList(model, authentication: authentication, completion: completionHandler)
                    }
                }
            }
        }
    }

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
        log.trace()
        stopTracing()
        Default.shared.lastLoadedBatchReleaseTime = nil
        Default.shared.lastSync = nil
        Default.shared.didMarkAsInfected = false
        try database.emptyStorage()
        try database.destroyDatabase()
        secretKeyProvider.reset()
        URLCache.shared.removeAllCachedResponses()
    }

    @objc func backgroundRefreshStatusDidChange() {
        state.backgroundRefreshState = UIApplication.shared.backgroundRefreshStatus
    }

    #if CALIBRATION
    func getLogs() throws -> [LogEntry] {
        return try database.loggingStorage.getLogs()
    }
    #endif

}

// MARK: BluetoothPermissionDelegate implementation

@available(iOS 13.5, *)
extension DP3TSDK: TracerDelegate {
    func stateDidChange() {
        state.trackingState = tracer.state
    }
}
