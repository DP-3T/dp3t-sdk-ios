/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Model of the exposed person
struct ExposeeModel: Encodable {
    /// Secret key used to generate EphID (base64 encoded)
    let key: Data

    /// The onset date of the secret key (format: yyyy-MM-dd)
    let onset: String

    /// Authentication data provided by health institutes to verify test results
    let authData: ExposeeAuthData
}
