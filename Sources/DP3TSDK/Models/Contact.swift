/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

/// Mobdel used for grouping and filtering Handshakes
struct Contact {
    let ephID: Data
    var handshakes: [HandshakeModel]
}

extension Contact: Equatable {}
