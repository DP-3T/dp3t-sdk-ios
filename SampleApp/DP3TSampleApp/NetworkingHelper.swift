
import Alamofire
import UIKit
import ExposureNotification
import CommonCrypto
import ZIPFoundation

struct CodableDiagnosisKey: Codable, Equatable, Hashable {
    let keyData: Data
    let rollingPeriod: UInt32
    let rollingStartNumber: UInt32
    let transmissionRiskLevel: UInt8
    let fake: UInt8
}

struct ExposeeListModel: Encodable {
    let gaenKeys: [CodableDiagnosisKey]
    let fake: Bool

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode key
        try container.encode(gaenKeys, forKey: .gaenKeys)
        try container.encode(fake ? 1 : 0, forKey: .fake)
        let ts = Date().timeIntervalSince1970
        let day = ts - ts.truncatingRemainder(dividingBy: 60*60*24)
        try container.encode(Int(day / 600), forKey: .delayedKeyDate)
    }

    enum CodingKeys: CodingKey {
        case gaenKeys, fake, delayedKeyDate
    }
}

enum Endpoint {
    static func addGaenExposee(deviceName: String, data: ExposeeListModel) -> URLRequest? {
        let url = baseUrl.appendingPathComponent("v1").appendingPathComponent("debug").appendingPathComponent("exposed")
        guard let payload = try? JSONEncoder().encode(data) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(deviceName, forHTTPHeaderField: "X-Device-Name")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(String(payload.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = payload
        return request
    }

    static func getGaenExposee(batchReleaseTime: Date) -> URLRequest {
        let ts = batchReleaseTime.timeIntervalSince1970
        let day = Int(ts - ts.truncatingRemainder(dividingBy: 60*60*24)) * 1000
        let url = baseUrl.appendingPathComponent("v1").appendingPathComponent("debug").appendingPathComponent("exposed").appendingPathComponent("\(day)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

class NetworkingHelper {
    private var deviceToken: String {
        if let deviceToken: String = UserDefaults.standard.string(forKey: "org.dpppt.unique_device_token") {
            return deviceToken
        } else {
            let uuid = UUID().uuidString
            UserDefaults.standard.set(uuid, forKey: "org.dpppt.unique_device_token")
            return uuid
        }
    }

    struct UploadServerError: Error, Decodable {
        let error: String?
        let message: String?
        let path: String
        let status: Int
        let timestamp: Double
    }

    func uploadDatabase(fileUrl: URL, completion: ((Result<String, UploadServerError>) -> Void)?) {
        let url = URL(string: "https://dp3tdemoupload.azurewebsites.net/upload")!
        guard let databaseData = try? Data(contentsOf: fileUrl) else {
            completion?(.failure(UploadServerError(error: "Parsing error",
                                                   message: "Couldn't read file",
                                                   path: "",
                                                   status: 404,
                                                   timestamp: Date().timeIntervalSince1970)))
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let identifierPrefix = (Default.shared.identifierPrefix ?? "")
        let fileName = dateFormatter.string(from: Date()) + "_" + identifierPrefix + "_" + deviceToken + "_dp3t_callibration_db.sqlite"

        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(databaseData, withName: "file", fileName: fileName, mimeType: "application/sqlite")
        }, to: url)
            .response { response in
                if let responseData = response.data {
                    if let responseObject = try? JSONDecoder().decode(UploadServerError.self, from: responseData) {
                        completion?(.failure(responseObject))
                    } else if let string = String(data: responseData, encoding: .utf8) {
                        completion?(.success(string))
                    } else {
                        completion?(.failure(UploadServerError(error: "Upload Error",
                                                               message: "Unknown error",
                                                               path: "",
                                                               status: 400,
                                                               timestamp: Date().timeIntervalSince1970)))
                    }
                }
            }
    }

    public struct DebugZips: Hashable {
        let name: String
        let localUrl: URL
    }

    func getDebugKeys(day: Date, completionHandler: @escaping ([DebugZips]) -> Void){
        let request = Endpoint.getGaenExposee(batchReleaseTime: day)
        AF.download(request).response(completionHandler: { (response) in
            switch response.result {
            case let .success(url) where url != nil:
                guard let archive = ZIPFoundation.Archive(url: url!, accessMode: .read) else {
                    completionHandler([])
                    return
                }
                var result: [DebugZips] = []
                for entry in archive {
                    let localURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                        .appendingPathComponent(UUID().uuidString).appendingPathExtension("zip")
                    _ = try? archive.extract(entry, to: localURL)
                    result.append(.init(name: entry.path, localUrl: localURL))
                }
                completionHandler(result)
            default:
                completionHandler([])
                break
            }
        })
        
    }

    func uploadDebugKeys(debugName: String, completionHandler: @escaping (Result<Void, Error>) -> Void ){
        let manager = ENManager()
        manager.activate { (_) in
            manager.getTestDiagnosisKeys { (keys, error) in
                guard error == nil else {
                    manager.invalidate()
                    return
                }

                var keys = keys?.map(CodableDiagnosisKey.init(key:)) ?? []
                while(keys.count < 14) {
                    let ts = Date().timeIntervalSince1970
                    let day = ts - ts.truncatingRemainder(dividingBy: 60*60*24)
                    keys.append(.init(keyData: Crypto.generateRandomKey(lenght: 16),
                                      rollingPeriod: 144,
                                      rollingStartNumber: UInt32(day/600),
                                      transmissionRiskLevel: 0,
                                      fake: 1))
                }

                keys.sort { (lhs, rhs) -> Bool in
                    lhs.rollingStartNumber > rhs.rollingStartNumber
                }

                keys = Array(keys.prefix(14))



                let model = ExposeeListModel(gaenKeys: keys, fake: false)
                guard let request = Endpoint.addGaenExposee(deviceName: debugName, data: model) else {
                    manager.invalidate()
                    return
                }

                AF.request(request).response { (result) in
                    switch result.result {
                    case .success:
                        completionHandler(.success(()))
                    case let .failure(error):
                        completionHandler(.failure(error))
                    manager.invalidate()
                    }
                }
            }
        }


    }
}


@available(iOS 13.5, *)
extension CodableDiagnosisKey {
    init(key: ENTemporaryExposureKey) {
        keyData = key.keyData
        rollingPeriod = key.rollingPeriod
        rollingStartNumber = key.rollingStartNumber
        transmissionRiskLevel = key.transmissionRiskLevel
        fake = 0
    }
}

internal class Crypto {
    internal static func generateRandomKey(lenght: Int = Int(CC_SHA256_DIGEST_LENGTH)) -> Data {
        var keyData = Data(count: lenght)
        _ = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, lenght, $0.baseAddress!)
        }
        return keyData
    }

}
