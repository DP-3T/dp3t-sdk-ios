/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK

class KeyStoreMock: SecureStorageProtocol {
    var keys: [SecretKey] = []

    var ephIDs: EphIDsForDay?

    func getSecretKeys() throws -> [SecretKey] {
        return keys
    }

    func setSecretKeys(_ object: [SecretKey]) throws {
        keys = object
    }

    func getEphIDs() throws -> EphIDsForDay? {
        return ephIDs
    }

    func setEphIDs(_ object: EphIDsForDay) throws {
        ephIDs = object
    }

    func removeAllObject() {
        keys = []
        ephIDs = nil
    }
}
