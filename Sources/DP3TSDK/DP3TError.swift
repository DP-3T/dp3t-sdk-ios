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

/// SDK Errors
public enum DP3TTracingError: Error {
    /// NetworkingError
    case networkingError(error: DP3TNetworkingError)

    /// Error happend during known case synchronization
    case caseSynchronizationError(errors: [Error])

    /// The operation was cancelled
    case cancelled

    /// Expsure notification framework error
    case exposureNotificationError(error: Error)

    /// Bluetooth device turned off
    case bluetoothTurnedOff

    /// User has not been prompted for authorization yet (using startTracing() will prompt the user).
    case authorizationUnknown

    /// The user either denied authorization or region is not active
    case permissionError

    /// The user was marked as infected
    case userAlreadyMarkedAsInfected
}

/// A set of networking errors returned from the SDK
public enum DP3TNetworkingError: Error, Equatable {
    /// A generic error returned from the OS layer of networking
    case networkSessionError(error: Error)
    /// The response is not an HTTP response
    case notHTTPResponse
    /// An unexpected HTTP error state was returned
    case HTTPFailureResponse(status: Int, data: Data?)
    /// Response body was not expected to be empty
    case noDataReturned
    /// The returned body could not be parsed. The data might be in the wrong format or corrupted
    case couldNotParseData(error: Error, origin: Int)
    /// A body for a request could not be encoded
    case couldNotEncodeBody
    /// Device time differs from server time
    case timeInconsistency(shift: TimeInterval)
    /// JWT signature validation
    case jwtSignatureError(code: Int, debugDescription: String)

    /// An error code that uniquely identify an error.
    public var errorCode: Int {
        switch self {
        case .networkSessionError:
            return 100
        case .notHTTPResponse:
            return 200
        case .noDataReturned:
            return 300
        case .couldNotParseData(error: _, origin: let origin):
            assert(origin < 10)
            return 400 + origin
        case .couldNotEncodeBody:
            return 500
        case .timeInconsistency:
            return 700
        case let .HTTPFailureResponse(status: status, data: _):
            // Combines the HTTP Status error with the error
            return 8000 + status
        case .jwtSignatureError(code: let code, debugDescription: _):
            return 900 + code
        }
    }

    public static func == (lhs: DP3TNetworkingError, rhs: DP3TNetworkingError) -> Bool {
        return lhs.errorCode == rhs.errorCode
    }
}
