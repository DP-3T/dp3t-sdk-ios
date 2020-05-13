/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import os.log
#if CALIBRATION
    /// A logging delegate
    protocol LoggingDelegate: class {
        /// Log a string
        /// - Parameter LogType: the type of log
        /// - Parameter string: The string to log
        func log(_ string: String, type: OSLogType)
    }
#endif
