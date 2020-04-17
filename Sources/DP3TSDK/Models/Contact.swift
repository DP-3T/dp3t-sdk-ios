/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

/// Mobdel used for grouping and filtering Handshakes
struct Contact {
    let identifier: Int?
    let ephID: EphID
    let day: DayDate
    let associatedKnownCase: Int?
}

extension Contact: Equatable {}
