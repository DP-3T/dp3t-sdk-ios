/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

/// A delegate for the DP3T tracing
public protocol DP3TTracingDelegate: AnyObject {
    /// The state has changed
    /// - Parameter state: The new state
    func DP3TTracingStateChanged(_ state: TracingState)

    #if CALIBRATION
        func didAddLog(_ entry: LogEntry)
        func didAddHandshake(_ handshake: HandshakeModel)
    #endif
}

#if CALIBRATION
    public extension DP3TTracingDelegate {
        func didAddLog(_: LogEntry) {}
        func didAddHandshake(_: HandshakeModel) {}
    }
#endif

private var instance: DP3TSDK!

/// DP3TTracing
public enum DP3TTracing {
    /// initialize the SDK
    /// - Parameters:
    ///   - appId: application identifier used for the discovery call
    ///   - enviroment: enviroment to use
    ///   - urlSession: the url session to use for networking (can used to enable certificate pinning)
    public static func initialize(with appId: String, enviroment: Enviroment = .prod, urlSession: URLSession = .shared, mode: DP3TMode = .production) throws {
        guard instance == nil else {
            fatalError("DP3TSDK already initialized")
        }
        DP3TMode.current = mode
        instance = try DP3TSDK(appId: appId, enviroment: enviroment, urlSession: urlSession)
    }

    /// The delegate
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
    public static func startTracing() throws {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.startTracing()
    }

    /// Stops Bluetooth tracing
    public static func stopTracing() {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.stopTracing()
    }

    /// Triggers sync with the backend to refresh the exposed list
    /// - Parameter callback: callback
    public static func sync(callback: ((Result<Void, DP3TTracingErrors>) -> Void)?) throws {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.sync { result in
            DispatchQueue.main.async {
                callback?(result)
            }
        }
    }

    /// get the current status of the SDK
    /// - Parameter callback: callback
    public static func status(callback: (Result<TracingState, DP3TTracingErrors>) -> Void) {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.status(callback: callback)
    }

    /// tell the SDK that the user was exposed
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authString: Authentication string for the exposure change
    ///   - callback: callback
    public static func iWasExposed(onset: Date, authString: String, callback: @escaping (Result<Void, DP3TTracingErrors>) -> Void) {
        guard let instance = instance else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.iWasExposed(onset: onset, authString: authString, callback: callback)
    }

    /// reset the SDK
    public static func reset() throws {
        guard instance != nil else {
            fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.reset()
        instance = nil
    }

    #if CALIBRATION
        public static func startAdvertising() throws {
            guard let instance = instance else {
                fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
            }
            try instance.startAdvertising()
        }

        public static func startReceiving() throws {
            guard let instance = instance else {
                fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
            }
            try instance.startReceiving()
        }

        public static func getHandshakes(request: HandshakeRequest) throws -> HandshakeResponse {
            try instance.getHandshakes(request: request)
        }

        public static func getLogs(request: LogRequest) throws -> LogResponse {
            guard let instance = instance else {
                fatalError("DP3TSDK not initialized call `initialize(with:delegate:)`")
            }
            return try instance.getLogs(request: request)
        }

        public static func numberOfHandshakes() throws -> Int {
            try instance.numberOfHandshakes()
        }

        public static var isInitialized: Bool {
            return instance != nil
        }

        public static var reconnectionDelay: Int {
            get {
                return BluetoothConstants.peripheralReconnectDelay
            }
            set {
                BluetoothConstants.peripheralReconnectDelay = newValue
            }
        }
    #endif
}
