
import UIKit
import Alamofire

class UploadDatabaseHelper {

    private var deviceToken: String {
        get {
            if let deviceToken: String = UserDefaults.standard.string(forKey: "org.dpppt.unique_device_token") {
                return deviceToken
            } else {
                let uuid = UUID().uuidString
                UserDefaults.standard.set(uuid, forKey: "org.dpppt.unique_device_token")
                return uuid
            }
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
            .response { (response) in
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
}
