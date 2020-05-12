/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import ExposureNotification

protocol SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void)
    func reinitialize() throws
    func reset()
}


@available(iOS 13.5, *)
extension ENManager: SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        getDiagnosisKeys { keys, error in
            // getTestDiagnosisKeys { (keys, error) in
            if let error = error {
                completionHandler(.failure(.exposureNotificationError(error: error)))
            } else if let keys = keys {
                let filteredKeys = keys.filter { $0.date > onsetDate }.map(CodableDiagnosisKey.init(key:))
                completionHandler(.success(filteredKeys))
            } else {
                fatalError("getDiagnosisKeys returned neither an error nor a keys")
            }
        }
    }

    func reinitialize() {}

    func reset() {
        invalidate()
    }
}

@available(iOS 13.5, *)
extension CodableDiagnosisKey {
    init(key: ENTemporaryExposureKey) {
        keyData = key.keyData
        rollingPeriod = key.rollingPeriod
        rollingStartNumber = key.rollingStartNumber
        transmissionRiskLevel = key.transmissionRiskLevel
    }
}

@available(iOS 13.5, *)
extension ENTemporaryExposureKey {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(rollingStartNumber) * TimeInterval.minute * 10)
    }
}
