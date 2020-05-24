/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/**
 Synchronizes data on known cases
 */

class KnownCasesSynchronizer {
    private var defaults: DefaultStorage

    /// A DP3T matcher
    private weak var matcher: Matcher?

    private let descriptor: ApplicationDescriptor

    /// service client
    private weak var service: ExposeeServiceClientProtocol!

    private let log = Logger(KnownCasesSynchronizer.self, category: "knownCasesSynchronizer")

    private let queue = DispatchQueue(label: "org.dpppt.sync")

    /// Create a known case synchronizer
    /// - Parameters:
    ///   - matcher: The matcher for DP3T resolution and checks
    init(matcher: Matcher,
         service: ExposeeServiceClientProtocol,
         defaults: DefaultStorage = Default.shared,
         descriptor: ApplicationDescriptor) {
        self.matcher = matcher
        self.defaults = defaults
        self.service = service
        self.descriptor = descriptor
    }

    /// A callback result of async operations
    typealias Callback = (Result<Void, DP3TTracingError>) -> Void

    /// Synchronizes the local database with the remote one
    /// - Parameters:
    ///   - service: The service to use for synchronization
    ///   - callback: The callback once the task if finished
    func sync(now: Date = Date(), callback: Callback?) {
        log.trace()

        queue.sync {
            self.internalSync(now: now, callback: callback)
        }

    }

    private func internalSync(now: Date = Date(), callback: Callback?) {
        log.trace()
        let todayDate = DayDate(date: now).dayMin

        let minimumDate = todayDate.addingTimeInterval(-.day * Double(defaults.parameters.networking.daysToCheck - 1))

        var calendar = Calendar.current
        calendar.timeZone = Default.shared.parameters.crypto.timeZone
        let components = calendar.dateComponents([.day], from: minimumDate, to: todayDate)

        let daysToFetch = components.day ?? 0

        // cleanup old published after

        var publishedAfterStore = defaults.publishedAfterStore
        for date in publishedAfterStore.keys {
            if date < minimumDate {
                publishedAfterStore.removeValue(forKey: date)
            }
        }

        let dispatchGroup = DispatchGroup()
        let queue = OperationQueue()
        let synchronousQueue = DispatchQueue(label: "org.dpppt.internalSync")

        var occuredError: DP3TTracingError?

        for day in 0 ... daysToFetch {
            guard let currentKeyDate = calendar.date(byAdding: .day, value: day, to: minimumDate) else {
                continue
            }

            var publishedAfter: Date!
            synchronousQueue.sync {
                 publishedAfter = publishedAfterStore[currentKeyDate]
            }

            guard descriptor.mode == .test || publishedAfter == nil || publishedAfter! < Self.getLastDesiredSyncTime(ts: now) else {
                continue
            }

            dispatchGroup.enter()

            queue.addOperation { [weak self] in
                guard let self = self else { return }
                let result = self.service.getExposeeSynchronously(batchTimestamp: currentKeyDate)
                synchronousQueue.sync {
                    switch result {
                    case let .failure(error):
                        occuredError = .networkingError(error: error)
                        return
                    case let .success(knownCasesData):
                        do {

                            if let data = knownCasesData.data {
                                try self.matcher?.receivedNewKnownCaseData(data, keyDate: currentKeyDate)
                            }

                            publishedAfterStore[currentKeyDate] = knownCasesData.publishedUntil

                        } catch let error as DP3TNetworkingError {
                            self.log.error("matcher receive error: %@", error.localizedDescription)

                            occuredError = .networkingError(error: error)

                            return
                        } catch {
                            self.log.error("matcher receive error: %@", error.localizedDescription)

                            occuredError = .networkingError(error: .couldNotParseData(error: error, origin: 0))
                        }
                    }
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }

            do {
                try self.matcher?.finalizeMatchingSession()
            } catch {
                self.log.error("matcher finalize error: %@", error.localizedDescription)
                occuredError = .exposureNotificationError(error: error)
            }

            if let error = occuredError {
                callback?(.failure(error))
            } else {
                self.defaults.publishedAfterStore = publishedAfterStore
                callback?(.success(()))
            }
        }
    }

    internal static func getLastDesiredSyncTime(ts: Date = .init(), defaults: DefaultStorage = Default.shared) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.hour, .day, .month, .year], from: ts)
        if dateComponents.hour! < defaults.parameters.networking.syncHourMorning {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: ts)!
            return calendar.date(bySettingHour: defaults.parameters.networking.syncHourEvening, minute: 0, second: 0, of: yesterday)!
        } else if dateComponents.hour! < defaults.parameters.networking.syncHourEvening {
            return calendar.date(bySettingHour: defaults.parameters.networking.syncHourMorning, minute: 0, second: 0, of: ts)!
        } else {
            return calendar.date(bySettingHour: defaults.parameters.networking.syncHourEvening, minute: 0, second: 0, of: ts)!
        }
    }
}
