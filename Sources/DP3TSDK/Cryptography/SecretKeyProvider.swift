/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import ExposureNotification
import Foundation

protocol SecretKeyProvider: class {
    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void)

    func getDiagnosisKeys(onsetDate: Date?, appDesc: ApplicationDescriptor, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void)

    func reset()
}

private var logger = Logger(ENManager.self, category: "SecretKeyProvider")

extension ENManager: SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date?, appDesc: ApplicationDescriptor, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        logger.trace()
        let handler: ENGetDiagnosisKeysHandler = { [weak self] keys, error in
            guard let self = self else { return }
            if let error = error {
                log.error("getDiagnosisKeys error: %@", error.localizedDescription)
                completionHandler(.failure(.exposureNotificationError(error: error)))
            } else if let keys = keys {
                logger.info("received %d keys", keys.count)
                if let onsetDate = onsetDate {
                    var filteredKeys = keys.filter { $0.date > onsetDate }.map(CodableDiagnosisKey.init(key:))
                    filteredKeys.append(contentsOf: self.getFakeKeys(count: Default.shared.parameters.crypto.numberOfKeysToSubmit - filteredKeys.count))
                    filteredKeys.sort { (lhs, rhs) -> Bool in
                        lhs.rollingStartNumber > rhs.rollingStartNumber
                    }
                    filteredKeys = Array(filteredKeys.prefix(Default.shared.parameters.crypto.numberOfKeysToSubmit))
                    completionHandler(.success(filteredKeys))
                } else {
                    completionHandler(.success(keys.map(CodableDiagnosisKey.init(key:))))
                }

            } else {
                fatalError("getDiagnosisKeys returned neither an error nor a keys")
            }
        }

        switch appDesc.mode {
        case .production:
            logger.info("calling ENManager.getDiagnosisKeys")
            getDiagnosisKeys(completionHandler: handler)
        case .test:
            logger.info("calling ENManager.getDiagnosisKeys")
            getTestDiagnosisKeys(completionHandler: handler)
        }
    }

    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        logger.info("getFakeDiagnosisKeys")
        completionHandler(.success(getFakeKeys(count: Default.shared.parameters.crypto.numberOfKeysToSubmit)))
    }

    private func getFakeKeys(count: Int) -> [CodableDiagnosisKey] {
        guard count > 0 else { return [] }
        var keys: [CodableDiagnosisKey] = []
        let parameters = Default.shared.parameters
        for i in 0 ..< count {
            let day = DayDate(date: Date().addingTimeInterval(.day * Double(i) * (-1)))
            let rollingPeriod = UInt32(TimeInterval.day / (.minute * 10))
            let key = (try? Crypto.generateRandomKey(lenght: parameters.crypto.keyLength)) ?? Data(count: parameters.crypto.keyLength)
            keys.append(.init(keyData: key,
                              rollingPeriod: rollingPeriod,
                              rollingStartNumber: day.period,
                              transmissionRiskLevel: .zero,
                              fake: 1))
        }
        return keys
    }

    func reinitialize() {}

    func reset() {}
}

extension CodableDiagnosisKey {
    init(key: ENTemporaryExposureKey) {
        keyData = key.keyData
        rollingPeriod = key.rollingPeriod
        rollingStartNumber = key.rollingStartNumber
        transmissionRiskLevel = key.transmissionRiskLevel
        fake = 0
    }
}

extension ENTemporaryExposureKey {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(rollingStartNumber) * TimeInterval.minute * 10)
    }
}
