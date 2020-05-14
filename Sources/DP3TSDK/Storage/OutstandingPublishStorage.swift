/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

class OutstandingPublishStorage {

    let keychain: KeychainProtocol

    let key = KeychainKey<[OutstandingPublish]>(key: "org.dpppt.outstandingpublish")

    init(keychain: KeychainProtocol = Keychain()) {
        self.keychain = keychain
    }

    func get() -> [OutstandingPublish] {
        switch keychain.get(for: key) {
        case let .success(publishes):
            return publishes
        case .failure:
            return []
        }
    }

    func add(_ publish: OutstandingPublish) {
        var elements = get()
        elements.append(publish)
        set(publishes: elements)
    }

    func remove(publish: OutstandingPublish) {
        var elements = Set(get())
        elements.remove(publish)
        set(publishes: Array(elements))
    }

    func reset(){
        keychain.delete(for: key)
    }

    private func set(publishes: [OutstandingPublish]) {
        keychain.set(publishes, for: key)
    }
    
}
