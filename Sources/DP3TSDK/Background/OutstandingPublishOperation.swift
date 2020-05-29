/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

class OutstandingPublishOperation: Operation {
    weak var keyProvider: SecretKeyProvider!
    private let serviceClient: ExposeeServiceClient

    private let storage: OutstandingPublishStorage

    private let logger = Logger(OutstandingPublishOperation.self, category: "OutstandingPublishOperation")

    static let serialQueue = DispatchQueue(label: "org.dpppt.outstandingPublishQueue")

    init(keyProvider: SecretKeyProvider, serviceClient: ExposeeServiceClient, storage: OutstandingPublishStorage = OutstandingPublishStorage()) {
        self.keyProvider = keyProvider
        self.serviceClient = serviceClient
        self.storage = storage
    }

    override func main() {
        Self.serialQueue.sync {
            logger.trace()
            let operations = storage.get()
            guard operations.isEmpty == false else { return }
            logger.log("%{public}d operations in queue", operations.count)
            let today = DayDate().dayMin
            for op in operations where op.dayToPublish <= today {
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
                    keyProvider.getDiagnosisKeys(onsetDate: nil, appDesc: serviceClient.descriptor) { result in
                        switch result {
                        case let .success(keys):
                            let rollingStartNumber = DayDate(date: op.dayToPublish).period
                            key = keys.first(where: { $0.rollingStartNumber == rollingStartNumber })
                        case let .failure(error):
                            errorHappend = error
                        }
                        group.leave()
                    }
                }

                group.wait()

                if errorHappend != nil || key == nil {
                    if let error = errorHappend {
                        logger.error("error happend while retrieving key: %{public}@", error.localizedDescription)
                    } else {
                        logger.error("could not retrieve key")
                    }
                    self.cancel()
                    return
                }
                logger.log("received keys for %@", op.debugDescription)

                let model = DelayedKeyModel(delayedKey: key!, fake: op.fake)

                group.enter()
                serviceClient.addDelayedExposeeList(model, token: op.authorizationHeader) { result in
                    switch result {
                    case .success():
                        break
                    case let .failure(error):
                        errorHappend = error
                    }
                    group.leave()
                }

                group.wait()
                if errorHappend != nil {
                    if let error = errorHappend {
                        logger.error("error happend while publishing key %{public}@: %{public}@", op.debugDescription, error.localizedDescription)
                    }
                    self.cancel()
                    return
                }
                logger.log("successfully published %{public}@ removing publish from storage", op.debugDescription)
                storage.remove(publish: op)
            }
        }
    }
}
