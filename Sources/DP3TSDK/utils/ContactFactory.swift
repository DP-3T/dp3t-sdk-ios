/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

enum ContactFactory {
    static let badRssiThreshold: Double = -85.0
    //TODO: set correct value
    static let contactRssiThreshold: Double = -80.0
    //TODO: set correct value
    static let eventThreshold: Double = 0.8
    /// Helper function to create contacts from handshakes
    /// - Parameters:
    ///   - contactThreshold: how many handshakes to have to be recognized as contact
    /// - Returns: list of contacts
    static func contacts(from handshakes: [HandshakeModel], contactThreshold: Int = CryptoConstants.contactsThreshold) -> [Contact] {
        var groupedHandshakes = [EphID: [HandshakeModel]]()

        // group handhakes by id
        for handshake in handshakes {
            if groupedHandshakes.keys.contains(handshake.ephID) {
                groupedHandshakes[handshake.ephID]?.append(handshake)
            } else {
                groupedHandshakes[handshake.ephID] = [handshake]
            }
        }

        let contacts: [Contact] = groupedHandshakes.compactMap { element -> Contact? in
            //filter result to only contain ephIDs which have been seen more than contactThreshold times
            let ephID = element.key
            let handshakes = element.value

            let rssiValues: [(Date, Double)] = handshakes.compactMap { handshake -> (Date, Double)? in
                guard let rssi = handshake.RSSI else { return nil }
                guard rssi > ContactFactory.badRssiThreshold else { return nil }
                return (handshake.timestamp, rssi)
            }

            guard let firstValue = rssiValues.first else { return nil }

            let epochMean = rssiValues.map{ $0.1 }.reduce(0.0, +) / Double(rssiValues.count)

            guard epochMean < ContactFactory.contactRssiThreshold else { return nil }

            let epochStart = DP3TCryptoModule.getEpochStart(timestamp: firstValue.0)

            let windowMeans: [Double] = (0 ..< Int(CryptoConstants.secondsPerEpoch / TimeInterval.minute)).compactMap { (index) -> Double? in
                let start = epochStart.addingTimeInterval(TimeInterval(index) * .second)
                let end = start.addingTimeInterval(.minute)
                let values = rssiValues.filter { (timestamp, rssi) -> Bool in
                    return timestamp > start && timestamp < end
                }.map{ $0.1 }
                if values.isEmpty {
                    return nil
                } else {
                    return values.reduce(0.0, +) / Double(values.count)
                }
            }

            let eventDetectors: [Double] = windowMeans.map{ $0 / epochMean }

            for eventDetector in eventDetectors {
                if eventDetector > ContactFactory.eventThreshold {
                    let day = DayDate(date: firstValue.0)
                    return Contact(identifier: nil, ephID: ephID, day: day, associatedKnownCase: nil)
                }
            }

            return nil
        }

        return contacts
    }
}
