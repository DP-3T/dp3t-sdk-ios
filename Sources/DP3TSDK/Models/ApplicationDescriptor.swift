/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Model to describe the application endpoints
public struct ApplicationDescriptor: Codable {
    /// The app ID
    var appId: String
    /// The backend base URL to load buckets
    var bucketBaseUrl: URL
    /// The backend base URL to upload key
    var reportBaseUrl: URL
    /// The JWT public key
    var jwtPublicKey: Data?
    /// The contact person for the record
    internal var contact: String?
    /// A description of the service
    internal var description: String?

    public init(appId: String, bucketBaseUrl: URL, reportBaseUrl: URL, jwtPublicKey: Data?) {
        self.init(appId: appId, description: nil, jwtPublicKey: jwtPublicKey, bucketBaseUrl: bucketBaseUrl, reportBaseUrl: reportBaseUrl, contact: nil)
    }

    internal init(appId: String, description: String?, jwtPublicKey: Data?, bucketBaseUrl: URL, reportBaseUrl: URL, contact: String?) {
        self.appId = appId
        self.bucketBaseUrl = bucketBaseUrl
        self.reportBaseUrl = reportBaseUrl
        self.description = description
        self.contact = contact
        self.jwtPublicKey = jwtPublicKey
    }
}
