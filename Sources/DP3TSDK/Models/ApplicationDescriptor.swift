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
    /// The contact person for the record
    internal var contact: String?
    /// A description of the service
    internal var description: String?

    public init(appId: String, backendBaseUrl: URL) {
        self.appId = appId
        self.backendBaseUrl = backendBaseUrl
    }

    internal init(appId: String, description: String?, backendBaseUrl: URL, contact: String?) {
        self.appId = appId
        self.backendBaseUrl = backendBaseUrl
        self.description = description
        self.contact = contact
    }
}
