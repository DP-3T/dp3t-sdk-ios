/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import ExposureNotification
import Foundation
import ZIPFoundation

class ExposureNotificationMatcher: Matcher {
    weak var delegate: MatcherDelegate?

    private let manager: ENManager

    private let exposureDayStorage: ExposureDayStorage

    private let logger = Logger(ExposureNotificationMatcher.self, category: "matcher")

    private var localURLs: [Date: [URL]] = [:]

    private let defaults: DefaultStorage

    let synchronousQueue = DispatchQueue(label: "org.dpppt.matcher")

    init(manager: ENManager, exposureDayStorage: ExposureDayStorage, defaults: DefaultStorage = Default.shared) {
        self.manager = manager
        self.exposureDayStorage = exposureDayStorage
        self.defaults = defaults
    }

    func receivedNewKnownCaseData(_ data: Data, keyDate: Date) throws {
        logger.trace()

        if let archive = Archive(data: data, accessMode: .read) {
            logger.debug("unarchived archive")
            for entry in archive {
                let localURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                    .appendingPathComponent(UUID().uuidString).appendingPathComponent(entry.path)

                _ = try archive.extract(entry, to: localURL)

                synchronousQueue.sync {
                    self.logger.debug("found %@ item in archive", entry.path)
                    self.localURLs[keyDate, default: []].append(localURL)
                }
            }
        }
    }

    func finalizeMatchingSession() throws {
        logger.trace()
        try synchronousQueue.sync {
            guard localURLs.isEmpty == false else { return }

            for (day, urls) in localURLs {
                let semaphore = DispatchSemaphore(value: 0)
                var exposureSummary: ENExposureDetectionSummary?
                var exposureDetectionError: Error?
                let configuration: ENExposureConfiguration = .configuration()

                logger.log("calling detectExposures for day %@ and config: %@", day.description, configuration.description)
                manager.detectExposures(configuration: configuration, diagnosisKeyURLs: urls) { summary, error in
                    exposureSummary = summary
                    exposureDetectionError = error
                    semaphore.signal()
                }
                semaphore.wait()

                if let error = exposureDetectionError {
                    logger.error("ENManager.detectExposures failed error: %{public}@", error.localizedDescription)
                    throw error
                }

                try urls.forEach(deleteDiagnosisKeyFile(at:))

                if let summary = exposureSummary {
                    let computedThreshold: Double = (Double(truncating: summary.attenuationDurations[0]) * defaults.parameters.contactMatching.factorLow + Double(truncating: summary.attenuationDurations[1]) * defaults.parameters.contactMatching.factorHigh) / TimeInterval.minute

                    logger.log("reiceived exposureSummary: %{public}@ computed threshold: %{public}.2f (low:%{public}.2f, high: %{public}.2f) required %{public}d", summary.debugDescription, computedThreshold, defaults.parameters.contactMatching.factorLow, defaults.parameters.contactMatching.factorHigh, defaults.parameters.contactMatching.triggerThreshold)

                    if computedThreshold >= Double(defaults.parameters.contactMatching.triggerThreshold) {
                        logger.log("exposureSummary meets requiremnts")
                        let day: ExposureDay = ExposureDay(identifier: UUID(), exposedDate: day, reportDate: Date(), isDeleted: false)
                        exposureDayStorage.add(day)
                        delegate?.didFindMatch()
                    } else {
                        logger.log("exposureSummary does not meet requirements")
                    }
                }
            }
            localURLs.removeAll()
        }
    }

    func deleteDiagnosisKeyFile(at localURL: URL) throws {
        logger.trace()
        try FileManager.default.removeItem(at: localURL)
    }
}

extension ENExposureConfiguration {
    static func configuration(parameters: DP3TParameters = Default.shared.parameters) -> ENExposureConfiguration {
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
        configuration.metadata = ["attenuationDurationThresholds": [parameters.contactMatching.lowerThreshold,
                                                                    parameters.contactMatching.higherThreshold]]
        return configuration
    }
}
