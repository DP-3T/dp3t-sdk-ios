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


protocol Matcher: class {
    var timingManager: ExposureDetectionTimingManager? { get set }
    
    /// returns true if we found a match
    func receivedNewData(_ data: Data, keyDate: Date, now: Date) throws -> Bool 
}
