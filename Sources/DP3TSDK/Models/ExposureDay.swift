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

/// Mobdel used for showing exposure days
public struct ExposureDay: Equatable, Codable, Hashable {
    public let identifier: UUID
    public let exposedDate: Date
    public let reportDate: Date
    var isDeleted: Bool

    internal init(identifier: UUID, exposedDate: Date, reportDate: Date, isDeleted: Bool) {
        self.identifier = identifier
        self.exposedDate = DayDate(date: exposedDate).dayMin
        self.reportDate = reportDate
        self.isDeleted = isDeleted
    }

    internal func deleted() -> ExposureDay {
        .init(identifier: identifier, exposedDate: exposedDate, reportDate: reportDate, isDeleted: true)
    }
}
