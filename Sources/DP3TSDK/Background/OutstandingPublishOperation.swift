/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation

class OutstandingPublishOperation: Operation {
    weak var keyProvider: DiagnosisKeysProvider!
    private let serviceClient: ExposeeServiceClientProtocol

    private let storage: OutstandingPublishStorage

    private let logger = Logger(OutstandingPublishOperation.self, category: "OutstandingPublishOperation")

    private let runningInBackground: Bool

    private var defaults: DefaultStorage

    private var tracer: Tracer

    var now: Date {
        .init()
    }

    static let serialQueue = DispatchQueue(label: "org.dpppt.outstandingPublishQueue")

    init(keyProvider: DiagnosisKeysProvider,
         serviceClient: ExposeeServiceClientProtocol,
         storage: OutstandingPublishStorage = OutstandingPublishStorage(),
         runningInBackground: Bool,
         defaults: DefaultStorage = Default.shared,
         tracer: Tracer) {
        self.keyProvider = keyProvider
        self.serviceClient = serviceClient
        self.storage = storage
        self.runningInBackground = runningInBackground
        self.defaults = defaults
        self.tracer = tracer
    }

    override func main() {
        Self.serialQueue.sync {
            logger.trace()
            let operations = storage.get()
            guard operations.isEmpty == false else { return }
            logger.log("%{public}d operations in queue", operations.count)
            let today = DayDate(date: now).dayMin
            let yesterday = today.addingTimeInterval(-.day)
            for op in operations {

                guard op.dayToPublish < today else {
                    // ignore outstanding keys which are still in the future
                    logger.log("skipping outstanding key %{public}@ until released by EN (one day after)", op.debugDescription)
                    continue
                }

                if op.dayToPublish < yesterday {
                    // ignore outstanding keys older than one day, upload token will be invalid
                    logger.log("skipping outstanding key %{public}@ because of age and removing publish from storage", op.debugDescription)
                    storage.remove(publish: op)

                    // if we are running on iOS > 13.7 we need to disable the tracing
                    if #available(iOS 13.7, *), !op.fake {
                        tracer.setEnabled(false, completionHandler: nil)
                    }
                    enableResettingOfInfectionStatus(fake: op.fake)
                    continue
                }

                if #available(iOS 13.6, *) {
                    // this was fixed by apple with iOS 13.6 beta 4
                    // (there is unfortunally no way to negate #available checks)
                } else {
                    if runningInBackground {
                        // skip publish if we are not in foreground since apple does not allow calles to EN.getDiagnosisKeys in background
                        logger.log("skipping outstanding key %{public}@ because we are not in foreground", op.debugDescription)
                        continue
                    }
                }

                logger.log("handling outstanding Publish %@", op.debugDescription)
                let group = DispatchGroup()

                var key: CodableDiagnosisKey?

                var errorHappend: Error?

                if op.fake {
                    group.enter()
                    keyProvider.getFakeDiagnosisKeys { result in
                        switch result {
                        case let .success(keys):
                            key = keys.first
                        case let .failure(error):
                            errorHappend = error
                        }
                        group.leave()
                    }
                } else {
                    // get all keys up until today
                    group.enter()

                    // if we are running on iOS > 13.7 we need to disable the tracing after retreiving the key
                    var disableAfterCompletion = false
                    if #available(iOS 13.7, *) {
                        disableAfterCompletion = true
                    }
                    keyProvider.getDiagnosisKeys(onsetDate: nil, appDesc: serviceClient.descriptor, disableExposureNotificationAfterCompletion: disableAfterCompletion) { result in
                        switch result {
                        case let .success(keys):
                            let rollingStartNumber = DayDate(date: op.dayToPublish).period
                            key = keys.first(where: { $0.rollingStartNumber == rollingStartNumber && $0.fake == 0 })
                        case let .failure(error):
                            errorHappend = error
                        }
                        group.leave()
                    }
                }

                group.wait()

                if errorHappend != nil || key == nil {
                    if let error = errorHappend {
                        switch error as? DP3TTracingError {
                        case let .exposureNotificationError(error: error):
                            logger.error("error happend while retrieving key: %{public}@", error.localizedDescription)
                        default:
                            logger.error("error happend while retrieving key: %{public}@", error.localizedDescription)
                        }
                    } else {
                        logger.error("could not retrieve key")
                    }

                    enableResettingOfInfectionStatus(fake: op.fake)

                    logger.log("removing publish operation %{public}@ from storage", op.debugDescription)
                    storage.remove(publish: op)

                    self.cancel()
                    return
                }
                logger.log("received keys for %@", op.debugDescription)

                let model = DelayedKeyModel(delayedKey: key!, fake: op.fake)

                group.enter()
                serviceClient.addDelayedExposeeList(model, token: op.authorizationHeader) { result in
                    switch result {
                    case .success():
                        if op.fake {
                            DP3TTracing.activityDelegate?.fakeRequestCompleted(result: .success(200))
                        } else {
                            DP3TTracing.activityDelegate?.outstandingKeyUploadCompleted(result: .success(200))
                        }
                    case let .failure(error):
                        errorHappend = error
                        if op.fake {
                            DP3TTracing.activityDelegate?.fakeRequestCompleted(result: .failure(error))
                        } else {
                            DP3TTracing.activityDelegate?.outstandingKeyUploadCompleted(result: .failure(error))
                        }
                    }
                    group.leave()
                }

                group.wait()
                if errorHappend != nil {
                    if let error = errorHappend {
                        logger.error("error happend while publishing key %{public}@: %{public}@", op.debugDescription, error.localizedDescription)
                    }

                    logger.log("removing publish operation %{public}@ from storage", op.debugDescription)
                    storage.remove(publish: op)

                    enableResettingOfInfectionStatus(fake: op.fake)

                    self.cancel()
                    return
                }
                logger.log("successfully published %{public}@ removing publish from storage", op.debugDescription)
                storage.remove(publish: op)

                enableResettingOfInfectionStatus(fake: op.fake)
            }
        }
    }
    
    fileprivate func enableResettingOfInfectionStatus(fake: Bool){
        if !fake {
            self.logger.log("enabling resetting of infection status")
            self.defaults.infectionStatusIsResettable = true
        }
    }
}
