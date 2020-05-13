/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Mobdel used for showing exposure days
public struct ExposureDay: Equatable {
    public let identifier: Int
    public let exposedDate: Date
    public let reportDate: Date
    let isDeleted: Bool

    internal init(identifier: Int, exposedDate: Date, reportDate: Date, isDeleted: Bool) {
        self.identifier = identifier
        self.exposedDate = DayDate(date: exposedDate).dayMin
        self.reportDate = reportDate
        self.isDeleted = isDeleted
    }
}
