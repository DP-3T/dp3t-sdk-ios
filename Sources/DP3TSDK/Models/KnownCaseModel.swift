/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// A model for known cases
struct KnownCaseModel: Codable, Equatable {
    /// The identifier of the case
    let id: Int?
    /// The private key of the case
    let key: Data
    /// The day the known case was set as exposed
    let onset: Date
    /// The batch timestamp when the known case was published
    let batchTimestamp: Date

    init(id: Int?, key: Data, onset: Date, batchTimestamp: Date) {
        self.id = id
        self.key = key
        self.onset = onset
        self.batchTimestamp = batchTimestamp
    }

    init(proto: ProtoExposee, batchTimestamp: Date) {
        self.init(id: nil,
                  key: proto.key,
                  onset: Date(milliseconds: proto.keyDate),
                  batchTimestamp: batchTimestamp)
    }
}
