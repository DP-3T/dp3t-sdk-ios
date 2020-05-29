/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

class OutstandingPublishStorage {
    let keychain: KeychainProtocol

    private let logger = Logger(OutstandingPublishOperation.self, category: "OutstandingPublishStorage")

    static let key = KeychainKey<[OutstandingPublish]>(key: "org.dpppt.outstandingpublish")

    init(keychain: KeychainProtocol = Keychain()) {
        self.keychain = keychain
    }

    func get() -> [OutstandingPublish] {
        switch keychain.get(for: Self.key) {
        case let .success(publishes):
            return publishes
        case let .failure(error):
            switch error {
            case .notFound:
                break
            default:
                logger.error("could not access keychain error: %{public}@", error.localizedDescription)
            }
            return []
        }
    }

    func add(_ publish: OutstandingPublish) {
        logger.log("adding publish operation for %{public}@", publish.dayToPublish.debugDescription)
        var elements = get()
        elements.append(publish)
        set(publishes: elements)
    }

    func remove(publish: OutstandingPublish) {
        logger.log("removing publish operation for %{public}@", publish.dayToPublish.debugDescription)
        var elements = Set(get())
        elements.remove(publish)
        set(publishes: Array(elements))
    }

    func reset() {
        keychain.delete(for: Self.key)
    }

    private func set(publishes: [OutstandingPublish]) {
        keychain.set(publishes, for: Self.key)
    }
}
