/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation
import SwiftJWT
import UIKit

struct ExposeeSuccess {
    let data: Data?
    let publishedUntil: Date?
}

protocol ExposeeServiceClientProtocol: class {
    typealias ExposeeResult = Result<Data?, DP3TNetworkingError>
    typealias ExposeeCompletion = Result<Void, DP3TNetworkingError>

    var descriptor: ApplicationDescriptor { get }

    /// Get all exposee for a known day synchronously
    /// - Parameters:
    ///   - batchTimestamp: The batch timestamp
    /// - returns: array of objects or nil if they were already cached
    func getExposee(batchTimestamp: Date, completion: @escaping (Result<ExposeeSuccess, DP3TNetworkingError>) -> Void) -> URLSessionDataTask

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
    func detectTimeshift(response: HTTPURLResponse) -> DP3TNetworkingError? {
        guard let date = response.date else { return nil }

        let adjustedDate = date.addingTimeInterval(response.age)

        let timeShift = Date().timeIntervalSince(adjustedDate)

        log.log("detected timeshift is %{public}.2f", timeShift)

        if timeShift > Default.shared.parameters.networking.allowedServerTimeDiff {
            log.error("detected timeshift exceeds threshold %{public}.2f", Default.shared.parameters.networking.allowedServerTimeDiff)
            return .timeInconsistency(shift: timeShift)
        }

        return nil
    }

    /// Get all exposee for a known day
    /// - Parameters:
    ///   - batchTimestamp: The batch timestamp
    ///   - completion: The completion block
    /// - returns: array of objects or nil if they were already cached
    func getExposee(batchTimestamp: Date, completion: @escaping (Result<ExposeeSuccess, DP3TNetworkingError>) -> Void) -> URLSessionDataTask {
        log.log("getExposeeSynchronously for timestamp %{public}@ -> %lld", batchTimestamp.description, batchTimestamp.millisecondsSince1970)
        let url: URL = exposeeEndpoint.getExposeeGaen(batchTimestamp: batchTimestamp)

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
        request.setValue("application/zip", forHTTPHeaderField: "Accept")
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")

        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard error == nil else {
                completion(.failure(.networkSessionError(error: error!)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.notHTTPResponse))
                return
            }

            if let timeShiftError = self.detectTimeshift(response: httpResponse) {
                completion(.failure(timeShiftError))
                return
            }

            var publishedUntil: Date?
            if let publishedUntilHeader = httpResponse.value(forHTTPHeaderField: "x-published-until") {
                publishedUntil = try? .init(milliseconds: Int64(value: publishedUntilHeader))
            }

            let httpStatus = httpResponse.statusCode
            switch httpStatus {
            case 200:
                break
            case 204:
                // 204 response means there is no data for this day
                completion(.success(.init(data: nil, publishedUntil: publishedUntil)))
                return
            default:
                completion(.failure(.HTTPFailureResponse(status: httpStatus)))
                return
            }

            guard let responseData = data else {
                completion(.failure(.noDataReturned))
                return
            }

            // Validate JWT
            if #available(iOS 11.0, *), let verifier = self.jwtVerifier {
                do {
                    try verifier.verify(claimType: ExposeeClaims.self, httpResponse: httpResponse, httpBody: responseData)
                } catch let error as DP3TNetworkingError {
                    completion(.failure(error))
                    return
                } catch {
                    completion(.failure(DP3TNetworkingError.jwtSignatureError(code: 200, debugDescription: "Unknown error \(error)")))
                    return
                }
            }

            let result = ExposeeSuccess(data: responseData, publishedUntil: publishedUntil)
            completion(.success(result))
        }
        return task
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
        formatter.locale = Locale(identifier: "en")
        return formatter
    }()

    var date: Date? {
        guard let string = value(forHTTPHeaderField: "date") else { return nil }
        return HTTPURLResponse.dateFormatter.date(from: string)
    }

    var age: TimeInterval {
        guard let string = value(forHTTPHeaderField: "Age") else { return 0 }
        return TimeInterval(string) ?? 0
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
