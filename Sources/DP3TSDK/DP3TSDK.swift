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

    private let exposureDayStorage: ExposureDayStorage

    private var tracer: Tracer

    private let matcher: Matcher

    private let diagnosisKeysProvider: DiagnosisKeysProvider

    private let service: ExposeeServiceClientProtocol

    /// Synchronizes data on known cases
    private let synchronizer: KnownCasesSynchronizer

    /// the urlSession to use for networking
    private let urlSession: URLSession

    private let backgroundTaskManager: DP3TBackgroundTaskManager

    /// delegate
    public weak var delegate: DP3TTracingDelegate?

    private let log = Logger(DP3TSDK.self, category: "DP3TSDK")

    private var defaults: DefaultStorage

    /// keeps track of  SDK state
    private var state: TracingState {
        didSet {
            switch state.infectionStatus {
            case .infected:
                defaults.didMarkAsInfected = true
            default:
                defaults.didMarkAsInfected = false
            }
            defaults.lastSync = state.lastSync
            DispatchQueue.main.async {
                self.delegate?.DP3TTracingStateChanged(self.state)
            }
        }
    }

    /// Initializer
    /// - Parameters:
    ///   - applicationDescriptor: information about the backend to use
    ///   - urlSession: the url session to use for networking (app can set it to enable certificate pinning)
    ///   - backgroundHandler: handler which gets called on background execution
    convenience init(applicationDescriptor: ApplicationDescriptor,
                     urlSession: URLSession,
                     backgroundHandler: DP3TBackgroundHandler?) throws {
        // reset keychain on first launch
        let defaults = Default.shared
        if defaults.isFirstLaunch {
            defaults.isFirstLaunch = false
            let keychain = Keychain()
            keychain.delete(for: ExposureDayStorage.key)
            defaults.reset()
        }

        let exposureDayStorage = ExposureDayStorage()

        let manager = ENManager()
        let tracer = ExposureNotificationTracer(manager: manager)
        let matcher = ExposureNotificationMatcher(manager: manager, exposureDayStorage: exposureDayStorage)
        let diagnosisKeysProvider: DiagnosisKeysProvider = manager

        let service = ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: urlSession)

        let synchronizer = KnownCasesSynchronizer(matcher: matcher, service: service, descriptor: applicationDescriptor)

        let backgroundTaskManager = DP3TBackgroundTaskManager(handler: backgroundHandler, keyProvider: manager, serviceClient: service, tracer: tracer)

        self.init(applicationDescriptor: applicationDescriptor,
                  urlSession: urlSession,
                  tracer: tracer,
                  matcher: matcher,
                  diagnosisKeysProvider: diagnosisKeysProvider,
                  exposureDayStorage: exposureDayStorage,
                  service: service,
                  synchronizer: synchronizer,
                  backgroundTaskManager: backgroundTaskManager,
                  defaults: defaults)
    }


    init(applicationDescriptor: ApplicationDescriptor,
         urlSession: URLSession,
         tracer: Tracer,
         matcher: Matcher,
         diagnosisKeysProvider: DiagnosisKeysProvider,
         exposureDayStorage: ExposureDayStorage,
         service: ExposeeServiceClientProtocol,
         synchronizer: KnownCasesSynchronizer,
         backgroundTaskManager: DP3TBackgroundTaskManager,
         defaults: DefaultStorage) {

        self.applicationDescriptor = applicationDescriptor
        self.urlSession = urlSession
        self.tracer = tracer
        self.matcher = matcher
        self.diagnosisKeysProvider = diagnosisKeysProvider
        self.exposureDayStorage = exposureDayStorage
        self.service = service
        self.synchronizer = synchronizer
        self.backgroundTaskManager = backgroundTaskManager
        self.defaults = defaults

        self.state = TracingState(trackingState: .initialization,
                                  lastSync: defaults.lastSync,
                                  infectionStatus: InfectionStatus.getInfectionState(from: exposureDayStorage),
                                  backgroundRefreshState: UIApplication.shared.backgroundRefreshStatus)

        self.tracer.delegate = self
        self.synchronizer.delegate = self
        self.backgroundTaskManager.register()

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
    func startTracing(completionHandler: ((TracingEnableResult) -> Void)? = nil) {
        log.trace()
        if case .infected = state.infectionStatus {
            completionHandler?(.failure(DP3TTracingError.userAlreadyMarkedAsInfected))
            return
        }
        tracer.setEnabled(true, completionHandler: completionHandler)
    }

    /// stop tracing
    func stopTracing(completionHandler: ((TracingEnableResult) -> Void)? = nil) {
        log.trace()
        tracer.setEnabled(false, completionHandler: completionHandler)
    }

    /// Perform a new sync
    /// - Parameter callback: callback
    /// - Throws: if a error happed
    func sync(callback: ((SyncResult) -> Void)?) {
        log.trace()

        let group = DispatchGroup()

        let sync = {
            var storedResult: SyncResult?

            // Skip sync when tracing is not active
            if self.state.trackingState != .active {
                self.log.error("Skip sync when tracking is not active")
                storedResult = .skipped
            } else {
                group.enter()
                self.synchronizer.sync { result in
                    storedResult = result
                    group.leave()
                }
            }

            group.notify(queue: .main) { [weak self] in
                guard let self = self,
                      let result = storedResult else { return }

                if result == .success {
                    self.state.lastSync = Date()
                }

                callback?(result)
            }
        }

        if self.state.trackingState == .initialization {
            tracer.addInitialisationCallback {
                sync()
            }
        } else  {
            sync()
        }
    }

    /// Cancel any ongoing snyc
    func cancelSync() {
        log.trace()
        synchronizer.cancelSync()
    }

    /// get the current status of the SDK
    var status: TracingState {
        log.log("retreiving status from SDK")
        return state
    }

    /// tell the SDK that the user was exposed
    /// This will stop tracing
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

        var diagnosisKeysResult: Result<[CodableDiagnosisKey], DP3TTracingError> = .success([])

        if isFakeRequest {
            group.enter()
            diagnosisKeysProvider.getFakeDiagnosisKeys { result in
                diagnosisKeysResult = result
                group.leave()
            }
        } else {
            group.enter()
            diagnosisKeysProvider.getDiagnosisKeys(onsetDate: onset, appDesc: applicationDescriptor, disableExposureNotificationAfterCompletion: false) { result in
                diagnosisKeysResult = result
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            switch diagnosisKeysResult {
            case let .failure(error):
                callback(.failure(error))
            case let .success(keys):

                var mutableKeys = keys
                // always make sure we fill up the keys to defaults.parameters.crypto.numberOfKeysToSubmit
                let fakeKeyCount = self.defaults.parameters.networking.numberOfKeysToSubmit - mutableKeys.count

                let oldestRollingStartNumber = keys.min { (a, b) -> Bool in a.rollingStartNumber < b.rollingStartNumber }?.rollingStartNumber ?? DayDate(date: .init(timeIntervalSinceNow: -.day)).period

                let startingFrom = Date(timeIntervalSince1970: Double(oldestRollingStartNumber) *  10 * .minute - .day)

                mutableKeys.append(contentsOf: self.diagnosisKeysProvider.getFakeKeys(count: fakeKeyCount, startingFrom: startingFrom))

                let model = ExposeeListModel(gaenKeys: mutableKeys,
                                             fake: isFakeRequest,
                                             delayedKeyDate: DayDate())

                self.service.addExposeeList(model, authentication: authentication) { [weak self] result in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            if !isFakeRequest {
                                self.state.infectionStatus = .infected
                                self.tracer.setEnabled(false, completionHandler: nil)
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

    /// reset exposure days
    func resetExposureDays() {
        exposureDayStorage.markExposuresAsDeleted()
        state.infectionStatus = InfectionStatus.getInfectionState(from: exposureDayStorage)
    }

    /// reset the infection status
    func resetInfectionStatus() {
        state.infectionStatus = .healthy
    }

    /// reset the SDK
    func reset() {
        state.infectionStatus = .healthy
        log.trace()
        stopTracing()
        defaults.reset()
        exposureDayStorage.reset()
        URLCache.shared.removeAllCachedResponses()
    }

    @objc func backgroundRefreshStatusDidChange() {
        let new = UIApplication.shared.backgroundRefreshStatus
        let old = state.backgroundRefreshState
        if old == .denied || old == .restricted, old != new {
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

extension DP3TSDK: KnownCasesSynchronizerDelegate {
    func didFindMatch() {
        state.infectionStatus = InfectionStatus.getInfectionState(from: exposureDayStorage)
    }
}
