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

protocol DiagnosisKeysProvider: class {
    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void)

    func getFakeKeys(count: Int, startingFrom: Date) -> [CodableDiagnosisKey]

    func getDiagnosisKeys(onsetDate: Date?, appDesc: ApplicationDescriptor, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void)
}

extension DiagnosisKeysProvider {
    func getFakeKeys(count: Int, startingFrom: Date) -> [CodableDiagnosisKey] {
        guard count > 0 else { return [] }
        var keys: [CodableDiagnosisKey] = []
        let parameters = Default.shared.parameters
        for i in 0 ..< count {
            let day = DayDate(date: startingFrom.addingTimeInterval(.day * Double(i) * (-1)))
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
}

fileprivate var logger = Logger(.main, category: "DiagnosisKeysProvider")

extension ENManager: DiagnosisKeysProvider {
    func getDiagnosisKeys(onsetDate: Date?, appDesc: ApplicationDescriptor, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        logger.trace()
        if !exposureNotificationEnabled {
            // Enable exposure notifications first, if currently not enabled (e.g. last day key)
            self.setExposureNotificationEnabled(true) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    logger.error("ENManager.setExposureNotificationEnabled error: %{public}@", error.localizedDescription)
                    completionHandler(.failure(.exposureNotificationError(error: error)))
                } else {
                    self.getDiagnosisKeysInternal(onsetDate: onsetDate, appDesc: appDesc, disableExposureNotificationAfterCompletion: true, completionHandler: completionHandler)
                }
            }
        } else {
            // Do not disable if it's currently already enabled
            self.getDiagnosisKeysInternal(onsetDate: onsetDate, appDesc: appDesc, disableExposureNotificationAfterCompletion: false, completionHandler: completionHandler)
        }
    }

    func getDiagnosisKeysInternal(onsetDate: Date?, appDesc: ApplicationDescriptor, disableExposureNotificationAfterCompletion: Bool, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        let handler: ENGetDiagnosisKeysHandler = { keys, error in
            // Disable again after completion
            if disableExposureNotificationAfterCompletion {
                self.setExposureNotificationEnabled(false) { _ in
                    // Ignore
                }
            }

            if let error = error {
                logger.error("ENManager.getDiagnosisKeys error: %{public}@", error.localizedDescription)
                completionHandler(.failure(.exposureNotificationError(error: error)))
            } else if let keys = keys {
                logger.log("received %d keys", keys.count)

                let oldestDate = DayDate(date: Date().addingTimeInterval(-Default.shared.parameters.crypto.maxAgeOfKeyToRetreive)).dayMin

                // make sure to never retreive keys older than maxNumberOfDaysToRetreive even if the onset date is older
                var filteredKeys = keys.filter { $0.date > oldestDate }

                // if a onsetDate was passed we filter the keys using it
                if let onsetDate = onsetDate {
                    filteredKeys = filteredKeys.filter { $0.date > onsetDate }
                }

                var transformedKeys = filteredKeys.map(CodableDiagnosisKey.init(key:))

                transformedKeys.sort { (lhs, rhs) -> Bool in
                    lhs.rollingStartNumber > rhs.rollingStartNumber
                }

                // never return more than numberOfKeysToSubmit
                transformedKeys = Array(transformedKeys.prefix(Default.shared.parameters.crypto.numberOfKeysToSubmit))

                completionHandler(.success(transformedKeys))
            } else {
                fatalError("getDiagnosisKeys returned neither an error nor a keys")
            }
        }

        switch appDesc.mode {
        case .production:
            logger.log("calling ENManager.getDiagnosisKeys")
            getDiagnosisKeys(completionHandler: handler)
        case .test:
            logger.log("calling ENManager.getTestDiagnosisKeys")
            getTestDiagnosisKeys(completionHandler: handler)
        }
    }

    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        logger.log("getFakeDiagnosisKeys")
        completionHandler(.success(getFakeKeys(count: Default.shared.parameters.crypto.numberOfKeysToSubmit, startingFrom: .init(timeIntervalSinceNow: -.day))))
    }
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
