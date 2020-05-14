/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

struct CodableDiagnosisKey: Codable, Equatable {
    let keyData: Data
    let rollingPeriod: UInt32
    let rollingStartNumber: UInt32
    let transmissionRiskLevel: UInt8
    let fake: UInt8
}

/// Model of the exposed person
struct ExposeeListModel: Encodable {
    /// Secret keys
    let gaenKeys: [CodableDiagnosisKey]

    let fake: Bool

    let delayedKeyDate: DayDate

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode key
        try container.encode(gaenKeys, forKey: .gaenKeys)
 
        try container.encode(fake ? 1 : 0, forKey: .fake)

        try container.encode(delayedKeyDate.period, forKey: .delayedKeyDate)
    }

    enum CodingKeys: CodingKey {
        case gaenKeys, fake, delayedKeyDate
    }
}
