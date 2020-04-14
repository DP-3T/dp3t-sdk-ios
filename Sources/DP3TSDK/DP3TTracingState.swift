/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// The infection status of the user
public enum InfectionStatus: Int {
    /// The user is healthy and had no contact with any infected person
    case healthy
    /// The user is infected and has signaled it himself
    case infected
    /// The user was in contact with a person that was flagged as infected
    case exposed
}

/// The tracking state of the bluetooth and the other networking api
public enum TrackingState {
    /// The tracking is active and working fine
    case active

    #if CALIBRATION
        case activeReceiving
        case activeAdvertising
    #endif

    /// The tracking is stopped by the user
    case stopped
    /// The tracking is facing some issues that needs to be solved
    case inactive(error: DP3TTracingErrors)
}

/// The state of the API
public struct TracingState {
    /// The number of encounters with other people
    public var numberOfHandshakes: Int
    /// The tracking state of the bluetooth and the other networking api
    public var trackingState: TrackingState
    /// The last syncronization when the list of infected people was fetched
    public var lastSync: Date?
    /// The infection status of the user
    public var infectionStatus: InfectionStatus
}
