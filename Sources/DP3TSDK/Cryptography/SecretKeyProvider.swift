//

import Foundation

#if canImport(ExposureNotification)
import ExposureNotification
#endif


protocol SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void)
    func reinitialize() throws
    func reset()
}


extension DP3TCryptoModule: SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        do {
            let (day, key) = try getSecretKeyForPublishing(onsetDate: onsetDate)
            let rollingPeriod = UInt32(TimeInterval.day / (.minute * 10))
            let diagnosisKey = CodableDiagnosisKey(keyData: key,
                                                   rollingPeriod: rollingPeriod,
                                                   rollingStartNumber: day.period,
                                                   transmissionRiskLevel: 0)
            completionHandler(.success([diagnosisKey]))
        } catch let error as DP3TTracingError {
            completionHandler(.failure(error))
        } catch {
            completionHandler(.failure(DP3TTracingError.cryptographyError(error: "Cannot get secret key")))
        }
    }
}

@available(iOS 13.5, *)
extension ENManager: SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        getDiagnosisKeys { (keys, error) in
            if let error = error {
                completionHandler(.failure(.exposureNotificationError(error: error)))
            } else if let keys = keys {
                completionHandler(.success(keys.map(CodableDiagnosisKey.init(key: ))))
            } else {
                fatalError("getDiagnosisKeys returned neither an error nor a keys")
            }
        }
    }
    
    func reinitialize() { }

    func reset() {
        invalidate()
    }
}

@available(iOS 13.5, *)
extension CodableDiagnosisKey {
    init(key: ENTemporaryExposureKey) {
        self.keyData = key.keyData
        self.rollingPeriod = key.rollingPeriod
        self.rollingStartNumber = key.rollingStartNumber
        self.transmissionRiskLevel = key.transmissionRiskLevel
    }
}
