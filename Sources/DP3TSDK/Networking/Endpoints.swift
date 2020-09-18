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
    init(baseURL: URL, version: String = "v2") {
        self.baseURL = baseURL
        self.version = version
    }

    /// A versionned base URL
    private var baseURLVersionned: URL {
        baseURL.appendingPathComponent(version)
    }

    /// Get the URL for the exposed people endpoint at a day
    /// - Parameters:
    ///  - since: timestamp retreived from last sync
    func getExposee(since: Date?) -> URL {
        let url = baseURLVersionned.appendingPathComponent("gaen")
            .appendingPathComponent("exposed")

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let since = since {
            let milliseconds = since.millisecondsSince1970
            urlComponents?.queryItems = [
                URLQueryItem(name: "since", value: String(milliseconds))
            ]
        }

        guard let finalUrl = urlComponents?.url else {
            fatalError("can't create URLComponents url")
        }

        return finalUrl
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
    init(baseURL: URL, version: String = "v2") {
        self.baseURL = baseURL
        self.version = version
    }

    /// A versionned base URL
    private var baseURLVersionned: URL {
        baseURL.appendingPathComponent(version)
    }

    /// Get the add exposed endpoint URL
    func addExposedGaen() -> URL {
        baseURLVersionned.appendingPathComponent("gaen").appendingPathComponent("exposed")
    }

    /// Get the add exposed next day endpoint URL
    func addExposedGaenNextDay() -> URL {
        baseURLVersionned.appendingPathComponent("gaen").appendingPathComponent("exposednextday")
    }
}
