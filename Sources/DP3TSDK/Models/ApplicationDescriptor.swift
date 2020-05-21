/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Model to describe the application configuration
public struct ApplicationDescriptor {
    public init(appId: String, bucketBaseUrl: URL, reportBaseUrl: URL, jwtPublicKey: Data? = nil, mode: Mode = .production) {
        self.appId = appId
        self.bucketBaseUrl = bucketBaseUrl
        self.reportBaseUrl = reportBaseUrl
        self.jwtPublicKey = jwtPublicKey
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

    var mode: Mode = .production

    public enum Mode {
        case production
        case test
    }
}
