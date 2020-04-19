/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

enum ContactFactory {
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
            guard element.value.count > contactThreshold else { return nil }
            let day = DayDate(date: element.value.first!.timestamp)
            return Contact(identifier: nil, ephID: element.key, day: day, associatedKnownCase: nil)
        }

        return contacts
    }
}
