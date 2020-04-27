/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import UIKit
import SwiftJWT

protocol ExposeeServiceClientProtocol {
    typealias ExposeeResult = Result<[KnownCaseModel]?, DP3TNetworkingError>
    typealias ExposeeCompletion = Result<Void, DP3TNetworkingError>
    /// Get all exposee for a known day synchronously
    /// - Parameters:
    ///   - batchTimestamp: The batch timestamp
    ///   - completion: The completion block
    /// - returns: array of objects or nil if they were already cached
    func getExposeeSynchronously(batchTimestamp: Date) -> ExposeeResult

    /// Adds an exposee
    /// - Parameters:
    ///   - exposee: The exposee to add
    ///   - completion: The completion block
    ///   - authentication: The authentication to use for the request
    func addExposee(_ exposee: ExposeeModel, authentication: ExposeeAuthMethod, completion: @escaping (ExposeeCompletion) -> Void)
}

/// The client for managing and fetching exposee
class ExposeeServiceClient: ExposeeServiceClientProtocol {
    /// The descriptor to use for the fetch
    private let descriptor: ApplicationDescriptor
    /// The endpoint for getting exposee
    private let exposeeEndpoint: ExposeeEndpoint
    /// The endpoint for adding and removing exposee
    private let managingExposeeEndpoint: ManagingExposeeEndpoint

    private let urlSession: URLSession

    private let urlCache: URLCache

    private let jwtVerifier: JWTVerifier?

    /// The user agent to send with the requests
    private var userAgent: String {
        let appId = descriptor.appId
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0"
        let systemVersion = UIDevice.current.systemVersion

        return [appId, appVersion, "iOS", systemVersion].joined(separator: ";")
    }

    /// Initialize the client with a  descriptor
    /// - Parameter descriptor: The descriptor to use
    public init(descriptor: ApplicationDescriptor, urlSession: URLSession = .shared, urlCache: URLCache = .shared) {
        self.descriptor = descriptor
        self.urlSession = urlSession
        self.urlCache = urlCache
        exposeeEndpoint = ExposeeEndpoint(baseURL: descriptor.bucketBaseUrl)
        managingExposeeEndpoint = ManagingExposeeEndpoint(baseURL: descriptor.reportBaseUrl)
        if #available(iOS 11.0, *), let jwtPublicKey = descriptor.jwtPublicKey {
            jwtVerifier = JWTVerifier.es256(publicKey: jwtPublicKey)
        } else {
            jwtVerifier = nil
        }
    }

    /// Get all exposee for a known day synchronously
    /// - Parameters:
    ///   - batchTimestamp: The batch timestamp
    ///   - completion: The completion block
    /// - returns: array of objects or nil if they were already cached
    func getExposeeSynchronously(batchTimestamp: Date) -> Result<[KnownCaseModel]?, DP3TNetworkingError> {
        let url = exposeeEndpoint.getExposee(batchTimestamp: batchTimestamp)
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Accept")

        let (data, response, error) = urlSession.synchronousDataTask(with: request)

        guard error == nil else {
            return .failure(.networkSessionError(error: error!))
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.notHTTPResponse)
        }

        if let date = httpResponse.date,
            abs(Date().timeIntervalSince(date)) > NetworkingConstants.timeShiftThreshold {
                return .failure(.timeInconsistency(shift: Date().timeIntervalSince(date)))
        }

        let httpStatus = httpResponse.statusCode
        switch httpStatus {
        case 200:
            break
        case 404:
            // 404 not found response means there is no data for this day
            return .success([])
        default:
            return .failure(.HTTPFailureResponse(status: httpStatus))
        }

        guard let responseData = data else {
            return .failure(.noDataReturned)
        }

        // Validate JWT
        if let verifier = self.jwtVerifier {
            guard let jwtString = httpResponse.value(for: "Signature") else {
                return .failure(.jwtSignitureError(code: 1, debugDescription: "No Signature field found in the header of the response. If the app specifies a JWT public key certificate for verification use, the server must send a `Signature` header field"))
            }

            do {
                let jwt = try JWT<ExposeeClaims>(jwtString: jwtString, verifier: verifier)
                let validationResult = jwt.validateClaims(leeway: 10)
                guard validationResult == .success else {
                    return .failure(.jwtSignitureError(code: 2, debugDescription: "JWT signiture don't match"))
                }
                // Verify the batch time
                let batchReleaseTimeRaw = jwt.claims.batchReleaseTime
                let calimBatchTimestamp = try Int(value: batchReleaseTimeRaw) / 1000
                guard Int(batchTimestamp.timeIntervalSince1970) == calimBatchTimestamp else {
                    return .failure(.jwtSignitureError(code: 3, debugDescription: "Batch release time missmatch"))
                }

                // Verify the hash
                let claimContentHash = Data(base64Encoded: jwt.claims.contentHash)
                let computedContentHash = Crypto.sha256(responseData)
                guard claimContentHash == computedContentHash else {
                    return .failure(.jwtSignitureError(code: 4, debugDescription: "Content Hash missmatch"))
                }

            } catch {
                return .failure(.jwtSignitureError(code: 5, debugDescription: "Generic JWC framework error \(error.localizedDescription)"))
            }
        }

        do {
            let protoList = try ProtoExposedList(serializedData: responseData)

            guard protoList.batchReleaseTime == batchTimestamp.millisecondsSince1970 else {
                return .failure(.batchReleaseTimeMissmatch)
            }

            let transformed: [KnownCaseModel] = protoList.exposed.map {
                KnownCaseModel(proto: $0, batchTimestamp: batchTimestamp)
            }
            return .success(transformed)
        } catch {
            return .failure(.couldNotParseData(error: error, origin: 1))
        }
    }

    /// Adds an exposee
    /// - Parameters:
    ///   - exposee: The exposee to add
    ///   - completion: The completion block
    ///   - authentication: The authentication to use for the request
    func addExposee(_ exposee: ExposeeModel, authentication: ExposeeAuthMethod, completion: @escaping (Result<Void, DP3TNetworkingError>) -> Void) {

        // addExposee endpoint
        let url = managingExposeeEndpoint.addExposee()

        guard let payload = try? JSONEncoder().encode(exposee) else {
            completion(.failure(.couldNotEncodeBody))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(String(payload.count), forHTTPHeaderField: "Content-Length")
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        if case let ExposeeAuthMethod.HTTPAuthorizationBearer(token: token) = authentication {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = payload

        let task = urlSession.dataTask(with: request, completionHandler: { data, response, error in
            guard error == nil else {
                completion(.failure(.networkSessionError(error: error!)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.notHTTPResponse))
                return
            }

            let statusCode = httpResponse.statusCode
            guard statusCode == 200 else {
                completion(.failure(.HTTPFailureResponse(status: statusCode)))
                return
            }

            completion(.success(()))
        })
        task.resume()
    }

    /// Returns the list of all available application descriptors registered with the backend
    /// - Parameters:
    ///   - enviroment: The environment to use
    ///   - completion: The completion block
    static func getAvailableApplicationDescriptors(enviroment: Enviroment, urlSession: URLSession = .shared , completion: @escaping (Result<[ApplicationDescriptor], DP3TNetworkingError>) -> Void) {
        let url = enviroment.discoveryEndpoint
        let request = URLRequest(url: url)

        let task = urlSession.dataTask(with: request, completionHandler: { data, response, error in
            guard error == nil else {
                completion(.failure(.networkSessionError(error: error!)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.notHTTPResponse))
                return
            }

            let statusCode = httpResponse.statusCode
            guard statusCode == 200 else {
                completion(.failure(.HTTPFailureResponse(status: statusCode)))
                return
            }

            guard let responseData = data else {
                completion(.failure(.noDataReturned))
                return
            }
            
            do {
                let discoveryResponse = try JSONDecoder().decode(DiscoveryServiceResponse.self, from: responseData)
                return completion(.success(discoveryResponse.applications))
            } catch {
                completion(.failure(.couldNotParseData(error: error, origin: 2)))
                return
            }
        })
        task.resume()
    }
}

internal extension HTTPURLResponse {
    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, dd MMMM yyyy HH:mm:ss ZZZ"
        return formatter
    }()

    var date: Date? {
        guard let string = value(for: "date") else { return nil }
        return HTTPURLResponse.dateFormatter.date(from: string)
    }

    func value(for key: String) -> String? {
        if #available(iOS 13.0, *) {
            return value(forHTTPHeaderField: key)
        } else {
            //https://bugs.swift.org/browse/SR-2429
            return (allHeaderFields as NSDictionary)[key] as? String
        }
    }
}

fileprivate struct ExposeeClaims: Claims {
    let iss: String
    let iat: Date
    let exp: Date
    let contentHash: String
    let batchReleaseTime: String
    let hashAlg: String

    enum CodingKeys: String, CodingKey {
        case contentHash = "content-hash"
        case batchReleaseTime = "batch-release-time"
        case hashAlg = "hash-alg"
        case iss, iat, exp
    }
}


fileprivate extension URLSession {
    func synchronousDataTask(with request: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        let dataTask = self.dataTask(with: request) {
            data = $0
            response = $1
            error = $2

            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)

        return (data, response, error)
    }
}
