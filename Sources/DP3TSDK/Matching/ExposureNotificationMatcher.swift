/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
#if canImport(ExposureNotification)
import ExposureNotification
#endif

@available(iOS 13.5, *)
class ExposureNotificationMatcher: Matcher {

    weak var delegate: MatcherDelegate?

    private let manager: ENManager

    private let database: DP3TDatabase

    private var localURLs: [Date: URL] = [:]

    init(manager: ENManager, database: DP3TDatabase) {
        self.manager = manager
        self.database = database
    }

    func receivedNewKnownCaseData(_ data: Data, batchTimestamp: Date) throws {
        let filename = String(Int(batchTimestamp.timeIntervalSince1970)) + ".key"
        let localURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("diagnosisKeys")
            .appendingPathComponent(filename)
        try data.write(to: localURL)
        localURLs[batchTimestamp] = localURL
    }

    func finalizeMatchingSession() throws {
        let semaphore = DispatchSemaphore(value: 0)
        var exposureSummary: ENExposureDetectionSummary?
        var exposureDetectionError: Error?
        let urls = localURLs.map { $0.value }
        manager.detectExposures(configuration: .dummyConfiguration, diagnosisKeyURLs: urls) { (summary, error) in
            exposureSummary = summary
            exposureDetectionError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let error = exposureDetectionError {
            throw error
        }

        try localURLs.map { $0.value }.forEach(deleteDiagnosisKeyFile(at:))
        localURLs.removeAll()

        //TODO: changed detection to more advanced logic
        if let summary = exposureSummary,
            summary.matchedKeyCount != 0 {
            let exposedDate = Date(timeIntervalSinceNow: TimeInterval(summary.daysSinceLastExposure) * TimeInterval.day * (-1))
            let day: ExposureDay = ExposureDay(identifier: 0, exposedDate: exposedDate, reportDate: Date())
            try database.exposureDaysStorage.add(day)
            delegate?.didFindMatch()
        }
    }

    func deleteDiagnosisKeyFile(at localURL: URL) throws {
        try FileManager.default.removeItem(at: localURL)
    }
}

@available(iOS 13.5, *)
extension ENExposureConfiguration {
    static var dummyConfiguration: ENExposureConfiguration = {
        let configuration = ENExposureConfiguration()
        configuration.minimumRiskScore = 0
        configuration.attenuationLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.attenuationWeight = 50
        configuration.daysSinceLastExposureLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.daysSinceLastExposureWeight = 50
        configuration.durationLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.durationWeight = 50
        configuration.transmissionRiskLevelValues = [1, 2, 3, 4, 5, 6, 7, 8]
        configuration.transmissionRiskWeight = 50
        return configuration
    }()
}
