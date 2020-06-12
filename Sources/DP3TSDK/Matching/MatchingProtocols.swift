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

/// A delegate used to respond on DP3T events
protocol MatcherDelegate: class {
    /// We found a match
    func didFindMatch()
}

protocol Matcher: class {
    var timingManager: ExposureDetectionTimingManager? { get set }

    var delegate: MatcherDelegate? { get set }

    func receivedNewData(_ data: Data, keyDate: Date, now: Date) throws
}
