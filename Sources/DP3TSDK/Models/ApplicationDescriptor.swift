/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Model to describe the application configuration
public struct ApplicationDescriptor: Codable {
    public init(appId: String, bucketBaseUrl: URL, reportBaseUrl: URL) {
        self.appId = appId
        self.bucketBaseUrl = bucketBaseUrl
        self.reportBaseUrl = reportBaseUrl
    }

    /// The app ID
    var appId: String
    /// The backend base URL to load buckets
    var bucketBaseUrl: URL
    /// The backend base URL to upload key
    var reportBaseUrl: URL
}
