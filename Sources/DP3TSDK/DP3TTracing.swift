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

/// A delegate for the DP3T tracing
public protocol DP3TTracingDelegate: AnyObject {
    /// The state has changed
    /// - Parameter state: The new state
    func DP3TTracingStateChanged(_ state: TracingState)
}

public protocol DP3TBackgroundHandler: AnyObject {
    func performBackgroundTasks(completionHandler: @escaping (_ success: Bool) -> Void)
    func didScheduleBackgrounTask()
}

private var instance: DP3TSDK!

/// DP3TTracing
public enum DP3TTracing {
    /// The current version of the SDK
    public static let frameworkVersion: String = "2.0.0"

    /// sets global parameter values which are used throughout the sdk
    public static var parameters: DP3TParameters {
        get {
            return Default.shared.parameters
        }
        set {
            Default.shared.parameters = newValue
        }
    }

    /// Determines if the OS is compatible with the DP3T SDK
    /// only in the case that the OS is compatible the Instance can be initialized
    public static var isOSCompatible: Bool {
        guard NSClassFromString("ENManager") != nil else {
            // between 13.0 and 13.5 where no Exposure Notification framework is available
            return false
        }

        if #available(iOS 13.7, *) {
            return true
        } else if #available(iOS 13.5, *) {
            // Not supportet between iOS 13.5 and 13.7
            return false
        }
        return true
    }

    /// initialize the SDK
    /// - Parameters:
    ///   - config: configuration describing the backend to use
    ///   - enviroment: enviroment to use
    ///   - urlSession: the url session to use for networking (can used to enable certificate pinning)
    ///   - backgroundHandler: a delegate to perform background tasks
    public static func initialize(with applicationDescriptor: ApplicationDescriptor,
                                  urlSession: URLSession = .shared,
                                  backgroundHandler: DP3TBackgroundHandler? = nil) {
        precondition(Self.isOSCompatible, "Operating System is not compatible")
        precondition(instance == nil, "DP3TSDK already initialized")
        instance = DP3TSDK(applicationDescriptor: applicationDescriptor,
                               urlSession: urlSession,
                               backgroundHandler: backgroundHandler)
    }

    private static func instancePrecondition(){
        precondition(instance != nil, "DP3TSDK not initialized call `initialize(with:delegate:)`")
    }

    /// The delegate
    public static var delegate: DP3TTracingDelegate? {
        set {
            instancePrecondition()
            instance.delegate = newValue
        }
        get {
            instance.delegate
        }
    }

    /// Starts tracing
    public static func startTracing(completionHandler: ((TracingEnableResult) -> Void)? = nil) {
        instancePrecondition()
        instance.startTracing(completionHandler: completionHandler)
    }

    /// Stops tracing
    public static func stopTracing(completionHandler: ((TracingEnableResult) -> Void)? = nil) {
        instancePrecondition()
        instance.stopTracing(completionHandler: completionHandler)
    }

    /// Triggers sync with the backend to refresh the exposed list
    /// - Parameter callback: callback
    public static func sync(callback: ((SyncResult) -> Void)?) {
        instancePrecondition()
        instance.sync() { result in
            DispatchQueue.main.async {
                callback?(result)
            }
        }
    }

    /// Cancel any ongoing snyc
    public static func cancelSync() {
        instancePrecondition()
        instance.cancelSync()
    }

    /// get the current status of the SDK
    public static var status: TracingState {
        instancePrecondition()
        return instance.status
    }

    /// tell the SDK that the user was exposed
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authentication: Authentication method
    ///   - isFakeRequest: indicates if the request should be a fake one. This method should be called regulary so people sniffing the networking traffic can no figure out if somebody is marking themself actually as exposed
    ///   - callback: callback
    public static func iWasExposed(onset: Date,
                                   authentication: ExposeeAuthMethod,
                                   isFakeRequest: Bool = false,
                                   callback: @escaping (Result<Void, DP3TTracingError>) -> Void) {
        instancePrecondition()
        instance.iWasExposed(onset: onset,
                             authentication: authentication,
                             isFakeRequest: isFakeRequest,
                             callback: callback)
    }

    /// reset exposure days

    public static func resetExposureDays() {
        instancePrecondition()
        instance.resetExposureDays()
    }

    /// reset the infection status

    public static func resetInfectionStatus() {
        instancePrecondition()
        instance.resetInfectionStatus()
    }

    /// reset the SDK

    public static func reset() {
        instancePrecondition()
        instance.reset()
        instance = nil
    }

    public static var loggingEnabled: Bool {
        set {
            Logger.loggingEnabled = newValue
        }
        get {
            Logger.loggingEnabled
        }
    }

    public static var loggingDelegate: LoggingDelegate? {
        set {
            Logger.delegate = newValue
        }
        get { nil }
    }

    public static weak var activityDelegate: ActivityDelegate?
}
