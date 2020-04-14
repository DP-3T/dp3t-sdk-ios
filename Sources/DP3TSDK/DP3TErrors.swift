/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// SDK Errors
public enum DP3TTracingErrors: Error {
    /// Networking Error
    case NetworkingError(error: Error?)

    /// Error happend during known case synchronization
    case CaseSynchronizationError

    /// Cryptography Error
    case CryptographyError(error: String)

    /// Databse Error
    case DatabaseError(error: Error)

    /// Bluetooth device turned off
    case BluetoothTurnedOff

    /// Bluetooth permission error
    case PermissonError
}
