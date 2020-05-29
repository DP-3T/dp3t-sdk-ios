/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import ExposureNotification
import Foundation
import os
import UIKit

/// Main class for handling SDK logic

class DP3TSDK {
    /// appId of this instance
    private let applicationDescriptor: ApplicationDescriptor

    private let outstandingPublishesStorage: OutstandingPublishStorage

    private let exposureDayStorage: ExposureDayStorage

    private var tracer: Tracer

    private let matcher: Matcher

    private let secretKeyProvider: SecretKeyProvider

    private let service: ExposeeServiceClient

    /// Synchronizes data on known cases
    private let synchronizer: KnownCasesSynchronizer

    /// the urlSession to use for networking
    private let urlSession: URLSession

    private let backgroundTaskManager: DP3TBackgroundTaskManager

    /// delegate
    public weak var delegate: DP3TTracingDelegate?

    private let log = Logger(DP3TSDK.self, category: "DP3TSDK")

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
    ///   - applicationDescriptor: information about the backend to use
    ///   - urlSession: the url session to use for networking (app can set it to enable certificate pinning)
    init(applicationDescriptor: ApplicationDescriptor, urlSession: URLSession, backgroundHandler: DP3TBackgroundHandler?) throws {
        // reset keychain on first launch
        if Default.shared.isFirstLaunch {
            Default.shared.isFirstLaunch = false
            let keychain = Keychain()
            keychain.delete(for: ExposureDayStorage.key)
            keychain.delete(for: OutstandingPublishStorage.key)
            Default.shared.reset()
        }

        self.applicationDescriptor = applicationDescriptor
        self.urlSession = urlSession

        exposureDayStorage = ExposureDayStorage()
        outstandingPublishesStorage = OutstandingPublishStorage()

        let manager = ENManager()
        tracer = ExposureNotificationTracer(manager: manager)
        matcher = ExposureNotificationMatcher(manager: manager, exposureDayStorage: exposureDayStorage)
        secretKeyProvider = manager

        let service_ = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: urlSession)

        service = service_
        synchronizer = KnownCasesSynchronizer(matcher: matcher, service: service_, descriptor: applicationDescriptor)

        backgroundTaskManager = DP3TBackgroundTaskManager(handler: backgroundHandler, keyProvider: manager, serviceClient: service_)

        state = TracingState(trackingState: .stopped,
                             lastSync: Default.shared.lastSync,
                             infectionStatus: InfectionStatus.getInfectionState(from: exposureDayStorage),
                             backgroundRefreshState: UIApplication.shared.backgroundRefreshStatus)

        backgroundTaskManager.register()

        tracer.delegate = self
        matcher.delegate = self

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
    func startTracing(completionHandler: ((Error?) -> Void)? = nil) throws {
        log.trace()
        if case .infected = state.infectionStatus {
            throw DP3TTracingError.userAlreadyMarkedAsInfected
        }
        tracer.setEnabled(true, completionHandler: completionHandler)
    }

    /// stop tracing
    func stopTracing(completionHandler: ((Error?) -> Void)? = nil) {
        log.trace()
        tracer.setEnabled(false, completionHandler: completionHandler)
    }

    /// Perform a new sync
    /// - Parameter callback: callback
    /// - Throws: if a error happed
    func sync(callback: ((Result<Void, DP3TTracingError>) -> Void)?) {
        log.trace()

        if ENManager.authorizationStatus != .authorized {
            log.error("cant run sync before being authorized")
            callback?(.success(()))
            return
        }

        let group = DispatchGroup()

        let outstandingPublishOperation = OutstandingPublishOperation(keyProvider: secretKeyProvider, serviceClient: service)
        group.enter()
        outstandingPublishOperation.completionBlock = {
            group.leave()
        }
        OperationQueue().addOperation(outstandingPublishOperation)

        group.enter()
        var storedResult: Result<Void, DP3TTracingError>?
        synchronizer.sync { result in
            storedResult = result
            group.leave()
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            switch storedResult! {
            case .success:
                self.state.lastSync = Date()
                callback?(.success(()))
            case let .failure(error):
                callback?(.failure(error))
            }
        }
    }

    /// Cancel any ongoing snyc
    func cancelSync() {
        log.trace()
        synchronizer.cancelSync()
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
            return
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
            secretKeyProvider.getDiagnosisKeys(onsetDate: onset, appDesc: applicationDescriptor) { result in
                secretKeyResult = result
                group.leave()
            }
        }

        group.notify(queue: .main) {
            switch secretKeyResult {
            case let .failure(error):
                callback(.failure(error))
            case let .success(keys):

                let model = ExposeeListModel(gaenKeys: keys,
                                             fake: isFakeRequest,
                                             delayedKeyDate: DayDate())

                self.service.addExposeeList(model, authentication: authentication) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case let .success(outstandingPublish):
                            if !isFakeRequest {
                                self?.state.infectionStatus = .infected
                            }

                            self?.outstandingPublishesStorage.add(outstandingPublish)

                            callback(.success(()))
                        case let .failure(error):
                            callback(.failure(.networkingError(error: error)))
                        }
                    }
                }
            }
        }
    }

    /// reset exposure days
    func resetExposureDays() throws {
        exposureDayStorage.markExposuresAsDeleted()
        state.infectionStatus = InfectionStatus.getInfectionState(from: exposureDayStorage)
    }

    /// reset the infection status
    func resetInfectionStatus() throws {
        state.infectionStatus = .healthy
    }

    /// reset the SDK
    func reset() throws {
        state.infectionStatus = .healthy
        log.trace()
        stopTracing()
        Default.shared.reset()
        outstandingPublishesStorage.reset()
        exposureDayStorage.reset()
        URLCache.shared.removeAllCachedResponses()
    }

    @objc func backgroundRefreshStatusDidChange() {
        let new = UIApplication.shared.backgroundRefreshStatus
        let old = state.backgroundRefreshState
        if (old == .denied || old == .restricted) && old != new {
            backgroundTaskManager.register()
        }
        state.backgroundRefreshState = UIApplication.shared.backgroundRefreshStatus
    }
}

// MARK: BluetoothPermissionDelegate implementation

extension DP3TSDK: TracerDelegate {
    func stateDidChange() {
        state.trackingState = tracer.state
    }
}

extension DP3TSDK: MatcherDelegate {
    func didFindMatch() {
        state.infectionStatus = InfectionStatus.getInfectionState(from: exposureDayStorage)
    }
}
