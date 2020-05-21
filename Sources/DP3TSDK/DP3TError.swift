/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// SDK Errors
public enum DP3TTracingError: Error {
    /// NetworkingError
    case networkingError(error: DP3TNetworkingError)

    /// Error happend during known case synchronization
    case caseSynchronizationError(errors: [Error])

    /// Database Error
    case databaseError(error: Error?)

    /// Expsure notification framework error

    case exposureNotificationError(error: Error)

    /// Bluetooth device turned off
    case bluetoothTurnedOff

    /// Bluetooth permission error
    case permissonError

    /// The user was marked as infected
    case userAlreadyMarkedAsInfected
}

/// A set of networking errors returned from the SDK
public enum DP3TNetworkingError: Error {
    /// A generic error returned from the OS layer of networking
    case networkSessionError(error: Error)
    /// The response is not an HTTP response
    case notHTTPResponse
    /// An unexpected HTTP error state was returned
    case HTTPFailureResponse(status: Int)
    /// Response body was not expected to be empty
    case noDataReturned
    /// The returned body could not be parsed. The data might be in the wrong format or corrupted
    case couldNotParseData(error: Error, origin: Int)
    /// A body for a request could not be encoded
    case couldNotEncodeBody
    /// The requested batch time doesn't match the returned one from the server.
    case batchReleaseTimeMissmatch
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
        case .batchReleaseTimeMissmatch:
            return 600
        case .timeInconsistency:
            return 700
        case let .HTTPFailureResponse(status: status):
            // Combines the HTTP Status error with the error
            return 8000 + status
        case .jwtSignatureError(code: let code, debugDescription: _):
            return 900 + code
        }
    }
}
