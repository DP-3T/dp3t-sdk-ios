/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Fetch the discovery data and stores it
class ApplicationSynchronizer {
    /// The storage of the data
    let storage: ApplicationStorage
    /// The enviroment
    let enviroment: Enviroment
    /// url session to use
    let urlSession: URLSession

    /// Create a synchronizer
    /// - Parameters:
    ///   - enviroment: The environment of the synchronizer
    ///   - storage: The storage
    ///   - urlSession: The urlSession to use
    init(enviroment: Enviroment, storage: ApplicationStorage, urlSession: URLSession) {
        self.storage = storage
        self.enviroment = enviroment
        self.urlSession = urlSession
    }

    /// Synchronize the local and remote data.
    /// - Parameter callback: A callback with the sync result
    func sync(callback: @escaping (Result<Void, DP3TTracingErrors>) -> Void) throws {
        ExposeeServiceClient.getAvailableApplicationDescriptors(enviroment: enviroment, urlSession: urlSession) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(ad):
                do {
                    try ad.forEach(self.storage.add(appDescriptor:))
                    callback(.success(()))
                } catch {
                    callback(.failure(DP3TTracingErrors.DatabaseError(error: error)))
                }
            case let .failure(error):
                callback(.failure(DP3TTracingErrors.NetworkingError(error: error)))
            }
        }
    }
}
