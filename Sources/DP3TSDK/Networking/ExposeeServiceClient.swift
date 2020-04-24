/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import UIKit
import SwiftJWT

/// The client for managing and fetching exposee
class ExposeeServiceClient {
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
        exposeeEndpoint = ExposeeEndpoint(baseURL: descriptor.reportBaseUrl)
        managingExposeeEndpoint = ManagingExposeeEndpoint(baseURL: descriptor.bucketBaseUrl)
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
    func getExposeeSynchronously(batchTimestamp: Date) -> Result<[KnownCaseModel]?, DP3TTracingError> {
        let url = exposeeEndpoint.getExposee(batchTimestamp: batchTimestamp)
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Accept")

        var existingEtag: String?
        if  let cache = urlCache.cachedResponse(for: request),
            let response = cache.response as? HTTPURLResponse,
            let etag = response.etag {
            existingEtag = etag
        }

        let (data, response, error) = urlSession.synchronousDataTask(with: request)

        // Compare new Etag with old one
        // We only need to process changed lists
        if let httpResponse = response as? HTTPURLResponse,
            let etag = httpResponse.etag {
            if etag == existingEtag {
                return .success(nil)
            } else if let date = httpResponse.date,
                      abs(Date().timeIntervalSince(date)) > NetworkingConstants.timeShiftThreshold {
                return .failure(.timeInconsistency(shift: Date().timeIntervalSince(date)))
            }
        }

        guard error == nil else {
            return .failure(.networkingError(error: error))
        }
        guard let responseData = data else {
            return .failure(.networkingError(error: nil))
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.networkingError(error: nil))
        }
        let statusCode = httpResponse.statusCode
        if statusCode == 404 {
            // 404 not found response means there is no data for this day
            return .success([])
        }

        // Validate JWT
        if let verifier = self.jwtVerifier {
            guard let jwtString = httpResponse.value(for: "Signature") else {
                return .failure(.jwtSignitureError)
            }

            do {
                let jwt = try JWT<ExposeeClaims>(jwtString: jwtString, verifier: verifier)
                let validationResult = jwt.validateClaims(leeway: 10)
                guard validationResult == .success else {
                    return .failure(.jwtSignitureError)
                }
                // Verify the batch time
                let batchReleaseTimeRaw = jwt.claims.batchReleaseTime
                let calimBatchTimestamp = try Int(value: batchReleaseTimeRaw) / 1000
                guard Int(batchTimestamp.timeIntervalSince1970) == calimBatchTimestamp else {
                    return .failure(.jwtSignitureError)
                }

                // Verify the hash
                let claimContentHash = Data(base64Encoded: jwt.claims.contentHash)
                let computedContentHash = Crypto.sha256(responseData)
                guard claimContentHash == computedContentHash else {
                    return .failure(.jwtSignitureError)
                }

            } catch {
                return .failure(.jwtSignitureError)
            }
        }

        guard statusCode == 200 else {
            return .failure(.networkingError(error: nil))
        }
        do {
            let protoList = try ProtoExposedList(serializedData: responseData)
            let transformed: [KnownCaseModel] = protoList.exposed.map {
                KnownCaseModel(proto: $0, batchTimestamp: batchTimestamp)
            }
            return .success(transformed)
        } catch {
            print(error.localizedDescription)
            return .failure(.networkingError(error: error))
        }
    }

    /// Adds an exposee
    /// - Parameters:
    ///   - exposee: The exposee to add
    ///   - completion: The completion block
    ///   - authentication: The authentication to use for the request
    func addExposee(_ exposee: ExposeeModel, authentication: ExposeeAuthMethod, completion: @escaping (Result<Void, DP3TTracingError>) -> Void) {

        // addExposee endpoint
        let url = managingExposeeEndpoint.addExposee()

        guard let payload = try? JSONEncoder().encode(exposee) else {
            completion(.failure(.networkingError(error: nil)))
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
                completion(.failure(.networkingError(error: error)))
                return
            }
            guard let responseData = data else {
                completion(.failure(.networkingError(error: nil)))
                return
            }
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                completion(.failure(.networkingError(error: nil)))
                return
            }
            guard statusCode == 200 else {
                completion(.failure(.networkingError(error: nil)))
                return
            }
            // string response
            _ = String(data: responseData, encoding: .utf8)
            completion(.success(()))
        })
        task.resume()
    }

    /// Returns the list of all available application descriptors registered with the backend
    /// - Parameters:
    ///   - enviroment: The environment to use
    ///   - completion: The completion block
    static func getAvailableApplicationDescriptors(enviroment: Enviroment, urlSession: URLSession = .shared , completion: @escaping (Result<[ApplicationDescriptor], DP3TTracingError>) -> Void) {
        let url = enviroment.discoveryEndpoint
        let request = URLRequest(url: url)

        let task = urlSession.dataTask(with: request, completionHandler: { data, response, error in
            guard error == nil else {
                completion(.failure(.networkingError(error: error)))
                return
            }
            guard let responseData = data else {
                completion(.failure(.networkingError(error: nil)))
                return
            }
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                completion(.failure(.networkingError(error: nil)))
                return
            }
            guard statusCode == 200 else {
                completion(.failure(.networkingError(error: nil)))
                return
            }
            do {
                let discoveryResponse = try JSONDecoder().decode(DiscoveryServiceResponse.self, from: responseData)
                return completion(.success(discoveryResponse.applications))
            } catch {
                completion(.failure(.networkingError(error: error)))
                return
            }
        })
        task.resume()
    }
}

internal extension HTTPURLResponse {
    var etag: String? {
        return value(for: "etag")
    }

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
