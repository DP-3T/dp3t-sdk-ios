/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CoreBluetooth
import Foundation
#if CALIBRATION
    public enum LogType: Int, CustomStringConvertible {
        case none = 0
        case receiver = 1
        case sender = 2
        case crypto = 3
        case sdk = 4
        case database = 5

        public var description: String {
            switch self {
            case .none:
                return "[]"
            case .receiver:
                return "[Receiver]"
            case .sender:
                return "[Sender]"
            case .sdk:
                return "[SDK]"
            case .crypto:
                return "[Crypo]"
            case .database:
                return "[Database]"
            }
        }
    }

    /// A logging delegate
    protocol LoggingDelegate: class {
        /// Log a string
        /// - Parameter LogType: the type of log
        /// - Parameter string: The string to log
        func log(type: LogType, _ string: String)
    }

    extension LoggingDelegate {
        /// Log
        /// - Parameters:
        ///   - state: The state
        ///   - prefix: A prefix
        func log(type: LogType, state: CBManagerState, prefix: String = "") {
            switch state {
            case .poweredOff:
                log(type: type, "\(prefix): poweredOff")
            case .poweredOn:
                log(type: type, "\(prefix): poweredOn")
            case .resetting:
                log(type: type, "\(prefix): resetting")
            case .unauthorized:
                log(type: type, "\(prefix): unauthorized")
            case .unknown:
                log(type: type, "\(prefix): unknown")
            case .unsupported:
                log(type: type, "\(prefix): unsupported")
        @unknown default:
                fatalError()
            }
        }
    }
#endif
