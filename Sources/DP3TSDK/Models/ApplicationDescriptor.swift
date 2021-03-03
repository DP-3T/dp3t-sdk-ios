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

/// Model to describe the application configuration
public struct ApplicationDescriptor {
    public init(appId: String, bucketBaseUrl: URL, reportBaseUrl: URL, jwtPublicKey: Data? = nil, withFederationGateway: Bool? = nil, mode: Mode = .production) {
        self.appId = appId
        self.bucketBaseUrl = bucketBaseUrl
        self.reportBaseUrl = reportBaseUrl
        self.jwtPublicKey = jwtPublicKey
        self.withFederationGateway = withFederationGateway
        self.mode = mode
    }

    /// The app ID
    var appId: String
    /// The backend base URL to load buckets
    var bucketBaseUrl: URL
    /// The backend base URL to upload key
    var reportBaseUrl: URL
    /// The JWT public key
    var jwtPublicKey: Data?

    var withFederationGateway: Bool?

    var mode: Mode = .production

    public enum Mode {
        case production
        case test
    }
}
