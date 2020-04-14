/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import UIKit

/// The client for managing and fetching exposee
class ExposeeServiceClient {
    /// The descriptor to use for the fetch
    private let descriptor: TracingApplicationDescriptor
    /// The endpoint for getting exposee
    private let exposeeEndpoint: ExposeeEndpoint
    /// The endpoint for adding and removing exposee
    private let managingExposeeEndpoint: ManagingExposeeEndpoint

    /// The user agent to send with the requests
    private var userAgent: String {
        let appId = descriptor.appId
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0"
        let systemVersion = UIDevice.current.systemVersion

        return [appId, appVersion, "iOS", systemVersion].joined(separator: ";")
    }

    /// Initialize the client with a  descriptor
    /// - Parameter descriptor: The descriptor to use
    public init(descriptor: TracingApplicationDescriptor) {
        self.descriptor = descriptor
        exposeeEndpoint = ExposeeEndpoint(baseURL: descriptor.backendBaseUrl)
        managingExposeeEndpoint = ManagingExposeeEndpoint(baseURL: descriptor.backendBaseUrl)
    }

    /// Get all exposee for a known day
    /// - Parameters:
    ///   - dayIdentifier: The day identifier
    ///   - completion: The completion block
    func getExposee(dayIdentifier: String, completion: @escaping (Result<[KnownCaseModel], DP3TTracingErrors>) -> Void) {
        let url = exposeeEndpoint.getExposee(forDay: dayIdentifier)

        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
            guard error == nil else {
                completion(.failure(.NetworkingError(error: error)))
                return
            }
            guard let responseData = data else {
                completion(.failure(.NetworkingError(error: nil)))
                return
            }
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                completion(.failure(.NetworkingError(error: nil)))
                return
            }
            if statusCode == 404 {
                // 404 not found response means there is no data for this day
                completion(.success([]))
                return
            }
            guard statusCode == 200 else {
                completion(.failure(.NetworkingError(error: nil)))
                return
            }
            do {
                let decoder = JSONDecoder()

                let dayData = try decoder.decode(KnownCasesResponse.self, from: responseData)

                completion(.success(dayData.exposed))
            } catch {
                completion(.failure(.NetworkingError(error: error)))
            }
        })
        task.resume()
    }

    /// Adds an exposee
    /// - Parameters:
    ///   - exposee: The exposee to add
    ///   - completion: The completion block
    func addExposee(_ exposee: ExposeeModel, completion: @escaping (Result<Void, DP3TTracingErrors>) -> Void) {
        exposeeEndpointRequest(exposee, action: .add) { result in
            switch result {
            case let .failure(error):
                completion(.failure(.NetworkingError(error: error)))
            case .success:
                completion(.success(()))
            }
        }
    }

    /// Removes an exposee
    /// - Parameters:
    ///   - exposee: The exposee to remove
    ///   - completion: The completion block
    func removeExposee(_ exposee: ExposeeModel, completion: @escaping (Result<Void, DP3TTracingErrors>) -> Void) {
        exposeeEndpointRequest(exposee, action: .remove) { result in
            switch result {
            case let .failure(error):
                completion(.failure(.NetworkingError(error: error)))
            case .success:
                completion(.success(()))
            }
        }
    }

    private enum ExposeeEndpointAction { case add, remove }
    /// Executes a managing exposee request
    /// - Parameters:
    ///   - exposee: The exposee to manage
    ///   - action: The action to perform
    ///   - completion: The completion block
    private func exposeeEndpointRequest(_ exposee: ExposeeModel, action: ExposeeEndpointAction, completion: @escaping (Result<Void, DP3TTracingErrors>) -> Void) {
        // addExposee endpoint
        let url: URL
        switch action {
        case .add:
            url = managingExposeeEndpoint.addExposee()
        case .remove:
            url = managingExposeeEndpoint.removeExposee()
        }

        guard let payload = try? JSONEncoder().encode(exposee) else {
            completion(.failure(.NetworkingError(error: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(String(payload.count), forHTTPHeaderField: "Content-Length")
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = payload

        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            guard error == nil else {
                completion(.failure(.NetworkingError(error: error)))
                return
            }
            guard let responseData = data else {
                completion(.failure(.NetworkingError(error: nil)))
                return
            }
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                completion(.failure(.NetworkingError(error: nil)))
                return
            }
            guard statusCode == 200 else {
                completion(.failure(.NetworkingError(error: nil)))
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
    static func getAvailableApplicationDescriptors(enviroment: Enviroment, completion: @escaping (Result<[TracingApplicationDescriptor], DP3TTracingErrors>) -> Void) {
        let url = enviroment.discoveryEndpoint
        let request = URLRequest(url: url)

        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            guard error == nil else {
                completion(.failure(.NetworkingError(error: error)))
                return
            }
            guard let responseData = data else {
                completion(.failure(.NetworkingError(error: nil)))
                return
            }
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                completion(.failure(.NetworkingError(error: nil)))
                return
            }
            guard statusCode == 200 else {
                completion(.failure(.NetworkingError(error: nil)))
                return
            }
            do {
                let discoveryResponse = try JSONDecoder().decode(DiscoveryServiceResponse.self, from: responseData)
                return completion(.success(discoveryResponse.applications))
            } catch {
                completion(.failure(.NetworkingError(error: error)))
                return
            }
        })
        task.resume()
    }
}
