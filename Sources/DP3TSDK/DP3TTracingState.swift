/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation
import UIKit.UIApplication

/// The infection status of the user
public enum InfectionStatus: Equatable {
    /// The user is healthy and had no contact with any infected person
    case healthy
    /// The user was in contact with a person that was flagged as infected
    case exposed(days: [ExposureDay])
    /// The user is infected and has signaled it himself
    case infected

    static func getInfectionState(from storage: ExposureDayStorage, defaults: DefaultStorage = Default.shared) -> InfectionStatus {
        guard defaults.didMarkAsInfected == false else {
            return .infected
        }

        let matchingDays = storage.getDays()
        if !matchingDays.isEmpty {
            return .exposed(days: matchingDays)
        } else {
            return .healthy
        }
    }

    public static func == (lhs: InfectionStatus, rhs: InfectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.healthy, .healthy): fallthrough
        case (.infected, .infected):
            return true
        case let (.exposed(lhsDays), .exposed(rhsDays)):
            return lhsDays == rhsDays
        default:
            return false
        }
    }
}

/// The tracking state of the bluetooth and the other networking api
public enum TrackingState: Equatable {
    /// The tracker is not fully initialized
    case initialization
    /// The tracking is active and working fine
    case active
    /// The tracking is stopped by the user
    case stopped
    /// The tracking is facing some issues that needs to be solved
    case inactive(error: DP3TTracingError)

    public static func == (lhs: TrackingState, rhs: TrackingState) -> Bool {
        switch (lhs, rhs) {
        case (.active, .active): fallthrough
        case (.initialization, initialization): fallthrough
        case (.stopped, stopped):
            return true
        case let (.inactive(lhsError), .inactive(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// The state of the API
public struct TracingState: Equatable {
    /// The tracking state of the bluetooth and the other networking api
    public var trackingState: TrackingState
    /// The last syncronization when the list of infected people was fetched
    public var lastSync: Date?
    /// The infection status of the user
    public var infectionStatus: InfectionStatus
    /// Indicates if the user has enabled backgorundRefresh
    public var backgroundRefreshState: UIBackgroundRefreshStatus
    /// Indicates if internationalisation is enabled
    public var includeInternationalKeys: Bool
}

/// Result of a sync
public enum SyncResult: Equatable {
    /// Sync was successful
    case success
    /// An error occured
    case failure(_ error: DP3TTracingError)
    /// tracing is not active / sdk is still be in initialization phase / sync is defered due to ratelimit
    case skipped

    public static func == (lhs: SyncResult, rhs: SyncResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success),
             (.skipped, .skipped):
            return true
        case let (.failure(lhsError), .failure(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
