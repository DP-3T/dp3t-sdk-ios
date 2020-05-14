/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
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
