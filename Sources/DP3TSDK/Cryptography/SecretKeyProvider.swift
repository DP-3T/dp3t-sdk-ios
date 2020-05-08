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

#if canImport(ExposureNotification)
@available(iOS 13.5, *)
extension ENManager: SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {

        getDiagnosisKeys { (keys, error) in
        //getTestDiagnosisKeys { (keys, error) in
            if let error = error {
                completionHandler(.failure(.exposureNotificationError(error: error)))
            } else if let keys = keys {
                let filteredKeys = keys.filter { $0.date > onsetDate }.map(CodableDiagnosisKey.init(key: ))
                completionHandler(.success(filteredKeys))
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

@available(iOS 13.5, *)
extension ENTemporaryExposureKey {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(rollingStartNumber) * TimeInterval.minute * 10)
    }
}
#endif
