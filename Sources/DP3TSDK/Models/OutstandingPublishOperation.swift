/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

struct OutstandingPublishOperation: Codable, Hashable {
    let authorizationHeader: String?
    let dayToPublish: Date
    let fake: Bool
}
