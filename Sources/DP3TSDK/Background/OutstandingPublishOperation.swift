/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

@available(iOS 13.5, *)
class OutstandingPublishOperation: Operation {
    weak var keyProvider: SecretKeyProvider!
    private let serviceClient: ExposeeServiceClient

    private let storage = OutstandingPublishStorage()

    private let log = Logger(OutstandingPublishOperation.self, category: "OutstandingPublishOperation")

    let serialQueue = DispatchQueue(label: "org.dpppt.outstandingPublishQueue")

    init(keyProvider: SecretKeyProvider, serviceClient: ExposeeServiceClient) {
        self.keyProvider = keyProvider
        self.serviceClient = serviceClient
    }

    override func main() {
        serialQueue.sync {
            log.trace()
            let operations = storage.get()
            guard operations.isEmpty == false else { return }
            let today = DayDate().dayMin
            for op in operations where op.dayToPublish < today  {
                log.info("handling outstanding Publish %@", op.debugDescription)
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
                    keyProvider.getDiagnosisKeys(onsetDate: nil) { result in
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
                    self.cancel()
                    return
                }

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
                    self.cancel()
                    return
                }
                storage.remove(publish: op)
            }
        }
    }
}
