//

import Foundation

#if canImport(ExposureNotification)
import ExposureNotification
#endif


protocol SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping (Result<[SecretKey], DP3TTracingError>) -> Void)
    func reinitialize() throws
    func reset()
}


extension DP3TCryptoModule: SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping (Result<[SecretKey], DP3TTracingError>) -> Void) {
        do {
            let (day, key) = try getSecretKeyForPublishing(onsetDate: onsetDate)
            completionHandler(.success([SecretKey(day: day, keyData: key)]))
        } catch let error as DP3TTracingError {
            completionHandler(.failure(error))
        } catch {
            completionHandler(.failure(DP3TTracingError.cryptographyError(error: "Cannot get secret key")))
        }
    }
}

@available(iOS 13.5, *)
extension ENManager: SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date, completionHandler: @escaping (Result<[SecretKey], DP3TTracingError>) -> Void) {
        getDiagnosisKeys { (keys, error) in
            if let error = error {
                completionHandler(.failure(.exposureNotificationError(error: error)))
            } else if let keys = keys {
                completionHandler(.success(keys.map(SecretKey.init(key: ))))
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
extension SecretKey {
    init(key: ENTemporaryExposureKey) {
        self.keyData = key.keyData
        let date = Date(timeIntervalSince1970: Double(key.rollingStartNumber) * TimeInterval.minute * 10.0)
        self.day = DayDate(date: date)
    }
}
