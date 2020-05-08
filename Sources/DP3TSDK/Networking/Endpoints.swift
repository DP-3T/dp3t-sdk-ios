/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// An endpoint for exposed people
struct ExposeeEndpoint {
    /// The base URL to derive the url from
    let baseURL: URL
    /// A version of the API
    let version: String
    /// Initialize the endpoint
    /// - Parameters:
    ///   - baseURL: The base URL of the endpoint
    ///   - version: The version of the API
    init(baseURL: URL, version: String = "v1") {
        self.baseURL = baseURL
        self.version = version
    }

    /// A versionned base URL
    private var baseURLVersionned: URL {
        baseURL.appendingPathComponent(version)
    }

    /// Get the URL for the exposed people endpoint at a day
    /// - Parameter batchTimestamp: batchTimestamp
    func getExposee(batchTimestamp: Date) -> URL {
        let milliseconds = batchTimestamp.millisecondsSince1970
        return baseURLVersionned.appendingPathComponent("exposed").appendingPathComponent(String(milliseconds))
    }

    /// Get the URL for the exposed people endpoint at a day for GAEN
    /// - Parameter batchTimestamp: batchTimestamp
    func getExposeeGaen(batchTimestamp: Date) -> URL {
        let milliseconds = batchTimestamp.millisecondsSince1970
        return baseURLVersionned.appendingPathComponent("gaen")
            .appendingPathComponent("exposed")
            .appendingPathComponent(String(milliseconds))
    }
}

/// An endpoint for adding and removing exposed people
struct ManagingExposeeEndpoint {
    /// The base URL to derive the url from
    let baseURL: URL
    /// A version of the API
    let version: String
    /// Initialize the endpoint
    /// - Parameters:
    ///   - baseURL: The base URL of the endpoint
    ///   - version: The version of the API
    init(baseURL: URL, version: String = "v1") {
        self.baseURL = baseURL
        self.version = version
    }

    /// A versionned base URL
    private var baseURLVersionned: URL {
        baseURL.appendingPathComponent(version)
    }

    /// Get the add exposee endpoint URL
    func addExposee() -> URL {
        baseURLVersionned.appendingPathComponent("exposed")
    }

    /// Get the add exposeeList endpoint URL
    func addExposeeGaen() -> URL {
        baseURLVersionned.appendingPathComponent("gaen").appendingPathComponent("exposed")
    }

    /// Get the remove exposee endpoint URL
    func removeExposee() -> URL {
        baseURLVersionned.appendingPathComponent("removeexposed")
    }
}
