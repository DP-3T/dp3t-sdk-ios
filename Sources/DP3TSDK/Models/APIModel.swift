/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// Model of the known cases
struct KnownCasesResponse: Decodable {
    /// All exposed known cases
    let exposed: [KnownCaseModel]
}

/// Model of the discovery of services
struct DiscoveryServiceResponse: Codable {
    /// All available applications
    let applications: [ApplicationDescriptor]
}
