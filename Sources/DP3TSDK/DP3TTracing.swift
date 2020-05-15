/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
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
    func performBackgroundTasks(completionHandler: (_ success: Bool) -> Void)
}

@available(iOS 13.5, *)
private var instance: DP3TSDK!

/// DP3TTracing
public enum DP3TTracing {
    /// The current version of the SDK
    public static let frameworkVersion: String = "0.1.12"

    /// sets global parameter values which are used throughout the sdk
    public static var parameters: DP3TParameters {
        get {
            return Default.shared.parameters
        }
        set {
            Default.shared.parameters = newValue
        }
    }

    /// initialize the SDK
    /// - Parameters:
    ///   - config: configuration describing the backend to use
    ///   - enviroment: enviroment to use
    ///   - urlSession: the url session to use for networking (can used to enable certificate pinning)
    ///   - backgroundHandler: a delegate to perform background tasks
    @available(iOS 13.5, *)
    public static func initialize(with applicationDescriptor: ApplicationDescriptor,
                                  urlSession: URLSession = .shared,
                                  mode: DP3TMode = .production,
                                  backgroundHandler: DP3TBackgroundHandler? = nil) throws {
        guard instance == nil else {
            fatalError("DP3TSDK already initialized")
        }
        DP3TMode.current = mode
        instance = try DP3TSDK(applicationDescriptor: applicationDescriptor,
                               urlSession: urlSession,
                               backgroundHandler: backgroundHandler)
    }

    /// The delegate
    @available(iOS 13.5, *)
    public static var delegate: DP3TTracingDelegate? {
        set {
            guard instance != nil else {
                fatalError("DP3TSDK not initialized")
            }
            instance.delegate = newValue
        }
        get {
            instance.delegate
        }
    }

    /// Starts Bluetooth tracing
    @available(iOS 13.5, *)
    public static func startTracing() throws {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.startTracing()
    }

    /// Stops Bluetooth tracing
    @available(iOS 13.5, *)
    public static func stopTracing() {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.stopTracing()
    }

    /// Triggers sync with the backend to refresh the exposed list
    /// - Parameter callback: callback
    @available(iOS 13.5, *)
    public static func sync(callback: ((Result<Void, DP3TTracingError>) -> Void)?) {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.sync { result in
            DispatchQueue.main.async {
                callback?(result)
            }
        }
    }

    /// get the current status of the SDK
    /// - Parameter callback: callback
    @available(iOS 13.5, *)
    public static func status(callback: (Result<TracingState, DP3TTracingError>) -> Void) {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.status(callback: callback)
    }

    /// tell the SDK that the user was exposed
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authString: Authentication string for the exposure change
    ///   - isFakeRequest: indicates if the request should be a fake one. This method should be called regulary so people sniffing the networking traffic can no figure out if somebody is marking themself actually as exposed
    ///   - callback: callback
    @available(iOS 13.5, *)
    public static func iWasExposed(onset: Date,
                                   authentication: ExposeeAuthMethod,
                                   isFakeRequest: Bool = false,
                                   callback: @escaping (Result<Void, DP3TTracingError>) -> Void) {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.iWasExposed(onset: onset,
                             authentication: authentication,
                             isFakeRequest: isFakeRequest,
                             callback: callback)
    }

    /// reset exposure days
    @available(iOS 13.5, *)
    public static func resetExposureDays() throws {
        guard instance != nil else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.resetExposureDays()
    }

    /// reset the infection status
    @available(iOS 13.5, *)
    public static func resetInfectionStatus() throws {
        guard instance != nil else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.resetInfectionStatus()
    }

    /// reset the SDK
    @available(iOS 13.5, *)
    public static func reset() throws {
        guard instance != nil else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.reset()
        instance = nil
    }

    public static var loggingDelegate: LoggingDelegate? {
        set {
            Logger.delegate = newValue
        }
        get { nil }
    }
}
