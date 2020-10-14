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
    ///  - lastPublishedKeyTag: last published key tag if one is stored
    func getExposee(lastPublishedKeyTag: Int64?, includeInternationalKeys: Bool) -> URL {
        let url = baseURLVersionned.appendingPathComponent("gaen")
            .appendingPathComponent("exposed")

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = []
        if let lastPublishedKeyTag = lastPublishedKeyTag {
            urlComponents?.queryItems?.append(
                URLQueryItem(name: "lastPublishedKeyTag", value: String(lastPublishedKeyTag))
            )
        }
        urlComponents?.queryItems?.append(
            URLQueryItem(name: "includeInternationalKeys", value: includeInternationalKeys ? "true" : "false")
        )

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
}
