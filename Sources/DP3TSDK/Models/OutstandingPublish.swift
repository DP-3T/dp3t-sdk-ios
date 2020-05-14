/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

struct OutstandingPublish: Codable, Hashable, CustomDebugStringConvertible {
    let authorizationHeader: String?
    let dayToPublish: Date
    let fake: Bool

    var debugDescription: String {
        "<OutstandingPublish fake: \(fake), day: \(dayToPublish.description)>"
    }
}
