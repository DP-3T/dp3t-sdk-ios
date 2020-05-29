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

/// An option for authenticating the Exposee Api
public enum ExposeeAuthMethod {
    /// No authentication
    case none
    /// Send the authentication as part the JSON payload
    case JSONPayload(token: String)
    /// Send the authentication as a HTTP Header Authentication bearer token
    case HTTPAuthorizationBearer(token: String)
}
