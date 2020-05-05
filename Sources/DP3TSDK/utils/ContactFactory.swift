/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

enum ContactFactory {

    /// Helper function to create contacts from handshakes
    /// - Returns: list of contacts
    static func contacts(from handshakes: [HandshakeModel]) -> [Contact] {
        let parameters = Default.shared.parameters.contactMatching
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
            let ephID = element.key
            let handshakes = element.value

            let attenutationValues: [(Date, Double)] = handshakes.compactMap { handshake -> (Date, Double)? in
                guard let rssi = handshake.RSSI else { return nil }

                let txPower = handshake.TXPowerlevel ?? parameters.defaultTxPowerLevel

                let attenuation = txPower - rssi

                return (handshake.timestamp, attenuation)
            }

            guard let firstValue = attenutationValues.first else { return nil }

            let epochStart = DP3TCryptoModule.getEpochStart(timestamp: firstValue.0)

            let windowLength = Int(Default.shared.parameters.crypto.secondsPerEpoch / parameters.windowDuration)

            var numberOfMatchingWindows = 0

            for windowIndex in 0 ..< windowLength {
                let start = epochStart.addingTimeInterval(Double(windowIndex) * parameters.windowDuration)
                let end = start.addingTimeInterval(parameters.windowDuration)

                let values = attenutationValues.filter { (timestamp, _) -> Bool in
                    timestamp > start && timestamp <= end
                }.map { $0.1 }

                guard !values.isEmpty else { continue }

                let windowMean = values.reduce(0.0, +) / Double(values.count)

                if windowMean < parameters.contactAttenuationThreshold {
                    numberOfMatchingWindows += 1
                }
            }

            if numberOfMatchingWindows != 0 {
                let timestamp = firstValue.0.timeIntervalSince1970
                let bucketTimestamp = timestamp - timestamp.truncatingRemainder(dividingBy: Default.shared.parameters.networking.batchLength)
                return Contact(identifier: nil,
                               ephID: ephID,
                               date: Date(timeIntervalSince1970: bucketTimestamp),
                               windowCount: numberOfMatchingWindows,
                               associatedKnownCase: nil)
            }

            return nil
        }

        return contacts
    }
}
