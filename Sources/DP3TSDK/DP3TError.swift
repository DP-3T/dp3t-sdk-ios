/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// SDK Errors
public enum DP3TTracingError: Error {
    /// Networking Error
    case networkingError(error: Error?)

    /// Error happend during known case synchronization
    case caseSynchronizationError(errors: [Error])

    /// Cryptography Error
    case cryptographyError(error: String)

    /// Databse Error
    case databaseError(error: Error?)

    /// Bluetooth device turned off
    case bluetoothTurnedOff

    /// Bluetooth permission error
    case permissonError

    /// Device time differs from server time
    case timeInconsistency(shift: TimeInterval)
}
