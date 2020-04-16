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
    static func contacts(from handshakes: [HandshakeModel], contactThreshold: Int) -> [Contact] {
        var contacts = [Data: Contact]()

        // group handhakes by id
        for handshake in handshakes {
            if contacts.keys.contains(handshake.ephID) {
                contacts[handshake.ephID]?.handshakes.append(handshake)
            } else {
                contacts[handshake.ephID] = Contact(ephID: handshake.ephID, handshakes: [handshake])
            }
        }

        //filter result to only contain ephIDs which have been seen more than contactThreshold times
        let filtered = contacts.filter { contact -> Bool in
            contact.value.handshakes.count > contactThreshold
        }
        
        return Array(filtered.values)
    }
}
