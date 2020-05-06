/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
#if canImport(ExposureNotification)
import ExposureNotification



@available(iOS 13.4, *)
class ExposureNotificationMatcher: Matcher {

    weak var delegate: MatcherDelegate?

    private let manager: ENManager

    private let database: DP3TDatabase


    init(manager: ENManager, database: DP3TDatabase) {
        self.manager = manager
        self.database = database
    }

    func checkNewKnownCases(_ knownCases: [KnownCaseModel]) throws {
        let session = ENExposureDetectionSession()

        var outstandingCases = knownCases

        while outstandingCases.isEmpty == false {
            let chunk = Array(outstandingCases.prefix(upTo: session.maximumKeyCount))
            outstandingCases.removeFirst(chunk.count)

            let convertedKeys = chunk.map { ENTemporaryExposureKey(knownCase: $0) }

            let semaphore = DispatchSemaphore(value: 0)

            var addDiagnosisKeysError: Error?

            session.addDiagnosisKeys(convertedKeys) { (error) in
                addDiagnosisKeysError = error
                semaphore.signal()
            }

            semaphore.wait()

            if let error = addDiagnosisKeysError {
                throw error
            }
        }

        var exposureDays: [ExposureDay] = []
        var getExposureInfoError: Error?
        var doneGettingExposureInfo = false


        while !doneGettingExposureInfo, getExposureInfoError == nil {
            let semaphore = DispatchSemaphore(value: 0)

            session.getExposureInfo(withMaximumCount: 100) {(newExposures, done, error) in
                if let exposures = newExposures {
                    exposureDays.append(contentsOf: exposures.map(ExposureDay.init(exposureInfo:)))
                }
                getExposureInfoError = error
                doneGettingExposureInfo = done

                semaphore.signal()
            }
            semaphore.wait()
        }

        if !exposureDays.isEmpty {
            try exposureDays.forEach(database.exposureDaysStorage.add(_:))
            delegate?.didFindMatch()
        }

        if let error = getExposureInfoError {
            throw error
        }

    }
}

@available(iOS 13.4, *)
extension ExposureDay {
    init(exposureInfo: ENExposureInfo) {
        identifier = 0
        exposedDate = exposureInfo.date
        reportDate = Date()
    }
}

@available(iOS 13.4, *)
extension ENTemporaryExposureKey {
    convenience init(knownCase: KnownCaseModel) {
        self.init()
        keyData = knownCase.key
        rollingStartNumber = UInt32(knownCase.batchTimestamp.timeIntervalSince1970 / (TimeInterval.minute * 10.0))
        transmissionRiskLevel = .invalid
    }
}

#endif
