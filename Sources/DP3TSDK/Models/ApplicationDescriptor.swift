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
    /// The backend base URL
    var backendBaseUrl: URL
    /// The JWT public key
    var jwtPublicKey: Data?
    /// The contact person for the record
    internal var contact: String?
    /// A description of the service
    internal var description: String?

    public init(appId: String, backendBaseUrl: URL, jwtPublicKey: Data) {
        self.init(appId: appId, description: nil, jwtPublicKey: jwtPublicKey, backendBaseUrl: backendBaseUrl, contact: nil)
    }

    internal init(appId: String, description: String?, jwtPublicKey: Data?, backendBaseUrl: URL, contact: String?) {
        self.appId = appId
        self.backendBaseUrl = backendBaseUrl
        self.description = description
        self.contact = contact
        self.jwtPublicKey = jwtPublicKey
    }
}
