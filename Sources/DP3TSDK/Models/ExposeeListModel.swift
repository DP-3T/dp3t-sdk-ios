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

struct CodableDiagnosisKey: Codable, Equatable {
    let keyData: Data
    let rollingPeriod: UInt32
    let rollingStartNumber: UInt32
    let transmissionRiskLevel: UInt8
    let fake: UInt8
}

extension CodableDiagnosisKey {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(rollingStartNumber) * TimeInterval.minute * 10)
    }
}

/// Model of the exposed person
struct ExposeeListModel: Encodable {
    /// Diagnosis keys
    let gaenKeys: [CodableDiagnosisKey]

    let withFederationGateway: Bool?

    let fake: Bool

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode key
        try container.encode(gaenKeys, forKey: .gaenKeys)
        if let withFederationGateway = withFederationGateway {
            try container.encode(withFederationGateway ? 1 : 0, forKey: .withFederationGateway)
        }
        try container.encode(fake ? 1 : 0, forKey: .fake)
    }

    enum CodingKeys: CodingKey {
        case gaenKeys, withFederationGateway, fake
    }
}
