/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

class ExposureDayStorage {
    let keychain: KeychainProtocol

    let parameters: DP3TParameters

    static let key = KeychainKey<[ExposureDay]>(key: "org.dpppt.exposureday")

    init(keychain: KeychainProtocol = Keychain(), parameters: DP3TParameters = Default.shared.parameters) {
        self.keychain = keychain
        self.parameters = parameters
        deleteExpiredExpsureDays()
    }

    var count: Int {
        getDays().count
    }

    func add(_ exposureDate: ExposureDay) {
        var days = getDays(filtered: false)
        // only append if the exposedDate is new
        if !days.contains(where: { $0.exposedDate == exposureDate.exposedDate }) {
            days.append(exposureDate)
            setDays(days: days)
        }
    }

    func setDays(days: [ExposureDay]) {
        keychain.set(days, for: Self.key)
    }

    func getDays(filtered: Bool = true) -> [ExposureDay] {
        switch keychain.get(for: Self.key) {
        case let .success(days):
            if filtered {
                return days.filter { $0.isDeleted == false }
            } else {
                return days
            }
        default:
            return []
        }
    }

    /// Deletes contacts older than CryptoConstants.numberOfDaysToKeepData
    func deleteExpiredExpsureDays() {
        let thresholdDate: Date = DayDate().dayMin.addingTimeInterval(-Double(parameters.crypto.numberOfDaysToKeepMatchedContacts) * TimeInterval.day)
        let days = getDays(filtered: false)
        let filteredDays = days.filter { $0.reportDate >= thresholdDate }
        setDays(days: filteredDays)
    }

    func markExposuresAsDeleted() {
        let days = getDays(filtered: false)
        setDays(days: days.map { $0.deleted() })
    }

    func reset() {
        keychain.delete(for: Self.key)
    }
}
