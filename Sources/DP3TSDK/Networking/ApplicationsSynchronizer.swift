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
    /// applicationInfo
    let appInfo: DP3TApplicationInfo
    /// url session to use
    let urlSession: URLSession

    private let log = OSLog(DP3TDatabase.self, category: "applicationSynchronizer")

    /// Create a synchronizer
    /// - Parameters:
    ///   - enviroment: The environment of the synchronizer
    ///   - storage: The storage
    ///   - urlSession: The urlSession to use
    init(appInfo: DP3TApplicationInfo, storage: ApplicationStorage, urlSession: URLSession) {
        self.storage = storage
        self.appInfo = appInfo
        self.urlSession = urlSession
    }

    /// Synchronize the local and remote data.
    /// - Parameter callback: A callback with the sync result
    func sync(callback: @escaping (Result<Void, DP3TTracingError>) -> Void) throws {
        log.trace()
        guard case let DP3TApplicationInfo.discovery(_, enviroment) = appInfo else {
            fatalError("ApplicationSynchronizer should not be used in manual mode")
        }
        ExposeeServiceClient.getAvailableApplicationDescriptors(enviroment: enviroment, urlSession: urlSession) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(ad):
                do {
                    try ad.forEach(self.storage.add(appDescriptor:))
                    callback(.success(()))
                } catch {
                    callback(.failure(DP3TTracingError.databaseError(error: error)))
                }
            case let .failure(error):
                callback(.failure(.networkingError(error: error)))
            }
        }
    }
}
