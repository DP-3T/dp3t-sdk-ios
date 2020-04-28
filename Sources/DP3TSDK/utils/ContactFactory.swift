/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

enum ContactFactory {
    static let defaultTxPowerLevel: Double = 12.0

    static let badAttenuationThreshold: Double = 64.0

    static let contactAttenuationThreshold: Double = 54.0

    static let eventThreshold: Double = 0.8

    static let numberOfWindowsForExposure: Int = 10

    static let windowDuration: TimeInterval = .minute

    /// Helper function to create contacts from handshakes
    /// - Returns: list of contacts
    static func contacts(from handshakes: [HandshakeModel]) -> [Contact] {
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

                let txPower = handshake.TXPowerlevel ?? ContactFactory.defaultTxPowerLevel

                let attenuation = abs(txPower) - rssi

                guard attenuation <= ContactFactory.badAttenuationThreshold else { return nil }

                return (handshake.timestamp, attenuation)
            }

            guard let firstValue = attenutationValues.first else { return nil }

            let epochMean = attenutationValues.map { $0.1 }.reduce(0.0, +) / Double(attenutationValues.count)

            let epochStart = DP3TCryptoModule.getEpochStart(timestamp: firstValue.0)

            let windowLength = Int(CryptoConstants.secondsPerEpoch / ContactFactory.windowDuration)

            var numberOfMatchingWindows = 0

            for windowIndex in 0 ..< windowLength {
                let start = epochStart.addingTimeInterval(Double(windowIndex) * ContactFactory.windowDuration)
                let end = start.addingTimeInterval(ContactFactory.windowDuration)

                let values = attenutationValues.filter { (timestamp, _) -> Bool in
                    timestamp > start && timestamp <= end
                }.map { $0.1 }

                guard !values.isEmpty else { continue }

                let windowMean = values.reduce(0.0, +) / Double(values.count)

                let eventDetector = windowMean / epochMean

                if eventDetector > ContactFactory.eventThreshold,
                    windowMean < ContactFactory.contactAttenuationThreshold {
                    numberOfMatchingWindows += 1
                }
            }

            if numberOfMatchingWindows != 0 {
                let timestamp = firstValue.0.timeIntervalSince1970
                let bucketTimestamp = timestamp - timestamp.truncatingRemainder(dividingBy: NetworkingConstants.batchLength)
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
