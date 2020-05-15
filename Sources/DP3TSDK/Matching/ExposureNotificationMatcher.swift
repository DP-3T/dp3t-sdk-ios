/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import ExposureNotification
import Foundation

@available(iOS 13.5, *)
class ExposureNotificationMatcher: Matcher {
    weak var delegate: MatcherDelegate?

    private let manager: ENManager

    private let exposureDayStorage: ExposureDayStorage

    private let log = Logger(ExposureNotificationMatcher.self, category: "matcher")

    private var localURLs: [Date: URL] = [:]

    init(manager: ENManager, exposureDayStorage: ExposureDayStorage) {
        self.manager = manager
        self.exposureDayStorage = exposureDayStorage
    }

    func receivedNewKnownCaseData(_ data: Data, batchTimestamp: Date) throws {
        log.trace()
        let filename = String(Int(batchTimestamp.timeIntervalSince1970))
        let localURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(filename)
        try data.write(to: localURL)
        localURLs[batchTimestamp] = localURL
    }

    func finalizeMatchingSession() throws {
        log.trace()
        guard localURLs.isEmpty == false else { return }

        let semaphore = DispatchSemaphore(value: 0)
        var exposureSummary: ENExposureDetectionSummary?
        var exposureDetectionError: Error?

        // TODO: call this method for each day
        let urls = localURLs.map { $0.value }
        log.info("calling detectExposures with %{public}d urls", urls.count)
        manager.detectExposures(configuration: .dummyConfiguration, diagnosisKeyURLs: urls) { summary, error in
            exposureSummary = summary
            exposureDetectionError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let error = exposureDetectionError {
            log.error("exposureNotificationError %@", error.localizedDescription)
            throw DP3TTracingError.exposureNotificationError(error: error)
        }

        try localURLs.map { $0.value }.forEach(deleteDiagnosisKeyFile(at:))
        localURLs.removeAll()

        if let summary = exposureSummary {
            log.info("reiceived exposureSummary: %@", summary.debugDescription)
        }

        // TODO: changed detection to more advanced logic
        // for now the attenuation duration < 50 has to be more than 15 minutes
        if let summary = exposureSummary,
            summary.attenuationDurations.count == 2,
            Double(truncating: summary.attenuationDurations[0]) > 15 * TimeInterval.minute {
            log.info("exposureSummary meets requiremnts")
            let exposedDate = Date(timeIntervalSinceNow: TimeInterval(summary.daysSinceLastExposure) * TimeInterval.day * (-1))
            let day: ExposureDay = ExposureDay(identifier: UUID(), exposedDate: exposedDate, reportDate: Date(), isDeleted: false)
            exposureDayStorage.add(day)
            delegate?.didFindMatch()
        } else {
            log.info("exposureSummary does not meet requirements")
        }
    }

    func deleteDiagnosisKeyFile(at localURL: URL) throws {
        log.trace()
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
