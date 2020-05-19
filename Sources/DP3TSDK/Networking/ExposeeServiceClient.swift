/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import SwiftJWT
import UIKit

struct ExposeeSuccess {
    let data: Data
    let publishedUntil: Date?
}

protocol ExposeeServiceClientProtocol: class {
    typealias ExposeeResult = Result<Data?, DP3TNetworkingError>
    typealias ExposeeCompletion = Result<Void, DP3TNetworkingError>
    /// Get all exposee for a known day synchronously
    /// - Parameters:
    ///   - batchTimestamp: The batch timestamp
    ///   - publishedAfter: get results published after the given timestamp
    /// - returns: array of objects or nil if they were already cached
    func getExposeeSynchronously(batchTimestamp: Date, publishedAfter: Date?) -> Result<ExposeeSuccess?, DP3TNetworkingError>

    /// Adds an exposee
    /// - Parameters:
    ///   - exposees: The exposee list to add
    ///   - completion: The completion block
    ///   - authentication: The authentication to use for the request
    func addExposeeList(_ exposees: ExposeeListModel, authentication: ExposeeAuthMethod, completion: @escaping (Result<OutstandingPublish, DP3TNetworkingError>) -> Void)

    /// Adds an exposee delayed key
    /// - Parameters:
    ///   - exposees: The exposee list to add
    ///   - token: authenticationToken
    ///   - completion: The completion block
    ///   - authentication: The authentication to use for the request
    func addDelayedExposeeList(_ model: DelayedKeyModel, token: String?, completion: @escaping (Result<Void, DP3TNetworkingError>) -> Void)
}

/// The client for managing and fetching exposee
class ExposeeServiceClient: ExposeeServiceClientProtocol {
    /// The descriptor to use for the fetch
    let descriptor: ApplicationDescriptor
    /// The endpoint for getting exposee
    private let exposeeEndpoint: ExposeeEndpoint
    /// The endpoint for adding and removing exposee
    private let managingExposeeEndpoint: ManagingExposeeEndpoint

    private let urlSession: URLSession

    private let urlCache: URLCache

    private let jwtVerifier: DP3TJWTVerifier?

    private let log = Logger(ExposeeServiceClient.self, category: "exposeeServiceClient")

    /// The user agent to send with the requests
    private var userAgent: String {
        let appId = descriptor.appId
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0"
        let buildNumber = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
        let systemVersion = UIDevice.current.systemVersion

        return [appId, appVersion, buildNumber, "iOS", systemVersion].joined(separator: ";")
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
            jwtVerifier = DP3TJWTVerifier(publicKey: jwtPublicKey, jwtTokenHeaderKey: "Signature")
        } else {
            jwtVerifier = nil
        }
    }

    /*

    https://demo-dpppt.ubique.ch/v1/gaen/exposed/1589673600000

    https://demo-dpppt.ubique.ch/v1/gaen/exposed/1589673600000&publishedAfter=1589838300000

    last 10 days

    [
    t-10: 1589838300000,
    t-9 : 1589838300000,
    ]

    20 x detect Exposured / day -> 2x each day group by day

    Response :
    x-published-until: 1589838300000
    */



    /// Get all exposee for a known day synchronously
    /// - Parameters:
    ///   - batchTimestamp: The batch timestamp
    ///   - completion: The completion block
    ///   - publishedAfter: get results published after the given timestamp
    /// - returns: array of objects or nil if they were already cached
    func getExposeeSynchronously(batchTimestamp: Date, publishedAfter: Date? = nil) -> Result<ExposeeSuccess?, DP3TNetworkingError> {
        log.debug("getExposeeSynchronously for timestamp %@ -> %lld", batchTimestamp.description, batchTimestamp.millisecondsSince1970)
        let url: URL = exposeeEndpoint.getExposeeGaen(batchTimestamp: batchTimestamp, publishedAfter: publishedAfter)

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
        request.setValue("application/zip", forHTTPHeaderField: "Accept")
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response, error) = urlSession.synchronousDataTask(with: request)

        guard error == nil else {
            return .failure(.networkSessionError(error: error!))
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.notHTTPResponse)
        }

        let httpStatus = httpResponse.statusCode
        switch httpStatus {
        case 200:
            break
        case 204:
            // 404 not found response means there is no data for this day
            return .success(nil)
        default:
            return .failure(.HTTPFailureResponse(status: httpStatus))
        }

        guard let responseData = data else {
            return .failure(.noDataReturned)
        }

        // Validate JWT
        if #available(iOS 11.0, *), let verifier = jwtVerifier {
            do {
                try verifier.verify(claimType: ExposeeClaims.self, httpResponse: httpResponse, httpBody: responseData)
            } catch let error as DP3TNetworkingError {
                return .failure(error)
            } catch {
                return .failure(DP3TNetworkingError.jwtSignatureError(code: 200, debugDescription: "Unknown error \(error)"))
            }
        }

        var publishedUntil: Date?
        if let publishedUntilHeader = httpResponse.value(forHTTPHeaderField: "x-published-until") {
            publishedUntil = try? .init(milliseconds: Int64(value: publishedUntilHeader))
        }

        let result = ExposeeSuccess(data: responseData, publishedUntil: publishedUntil)
        return .success(result)
    }

    /// Adds an exposee delayed key
    /// - Parameters:
    ///   - exposees: The exposee list to add
    ///   - token: authenticationToken
    ///   - completion: The completion block
    ///   - authentication: The authentication to use for the request
    func addDelayedExposeeList(_ model: DelayedKeyModel, token: String?, completion: @escaping (Result<Void, DP3TNetworkingError>) -> Void) {
        log.trace()
        // addExposee endpoint
        let url = managingExposeeEndpoint.addExposedGaenNextDay()

        guard let payload = try? JSONEncoder().encode(model) else {
            completion(.failure(.couldNotEncodeBody))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(String(payload.count), forHTTPHeaderField: "Content-Length")
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let authentication = token {
            request.addValue(authentication, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = payload

        let task = urlSession.dataTask(with: request, completionHandler: { _, response, error in
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

    /// Adds an exposee list
    /// - Parameters:
    ///   - exposees: The exposees to add
    ///   - completion: The completion block
    ///   - authentication: The authentication to use for the request
    func addExposeeList(_ exposees: ExposeeListModel, authentication: ExposeeAuthMethod, completion: @escaping (Result<OutstandingPublish, DP3TNetworkingError>) -> Void) {
        log.trace()
        // addExposee endpoint
        let url = managingExposeeEndpoint.addExposedGaen()

        guard let payload = try? JSONEncoder().encode(exposees) else {
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

        let task = urlSession.dataTask(with: request, completionHandler: { _, response, error in
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

            let outstandingPublish = OutstandingPublish(authorizationHeader: httpResponse.value(forHTTPHeaderField: "Authorization"),
                                                        dayToPublish: exposees.delayedKeyDate.dayMin,
                                                        fake: exposees.fake)

            completion(.success(outstandingPublish))
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
            // https://bugs.swift.org/browse/SR-2429
            return (allHeaderFields as NSDictionary)[key] as? String
        }
    }
}

private struct ExposeeClaims: DP3TClaims {
    let iss: String
    let iat: Date
    let exp: Date
    let contentHash: String
    let hashAlg: String

    enum CodingKeys: String, CodingKey {
        case contentHash = "content-hash"
        case hashAlg = "hash-alg"
        case iss, iat, exp
    }
}

private extension URLSession {
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
