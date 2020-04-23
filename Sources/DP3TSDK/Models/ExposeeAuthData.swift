/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// An option for authenticating the Exposee Api
public enum ExposeeAuthMethod {
    /// No authentication
    case none
    /// Send the authentication as part the JSON payload
    case JSONPayload(token: String)
    /// Send the authentication as a HTTP Header Authentication bearer token
    case HTTPAuthorizationBearer(token: String)
}
