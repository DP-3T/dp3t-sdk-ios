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
import os.log

/// A logging delegate
public protocol LoggingDelegate: class {
    /// Log a string
    /// - Parameter LogType: the type of log
    /// - Parameter string: The string to log
    func log(_ string: String, type: OSLogType)
}
