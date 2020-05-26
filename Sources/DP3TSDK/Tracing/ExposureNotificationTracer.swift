/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import ExposureNotification
import Foundation

class ExposureNotificationTracer: Tracer {
    private let manager: ENManager

    private var stateObservation: NSKeyValueObservation?
    private var enabledObservation: NSKeyValueObservation?

    var delegate: TracerDelegate?

    private let logger = Logger(ExposureNotificationTracer.self, category: "exposureNotificationTracer")

    private(set) var state: TrackingState {
        didSet {
            guard oldValue != state else { return }
            logger.log("state did change from %@ to %@", oldValue.debugDescription, state.debugDescription)
            delegate?.stateDidChange()
        }
    }

    init(manager: ENManager) {
        self.manager = manager

        state = .stopped

        logger.log("calling ENMananger.activate")
        manager.activate { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("ENMananger.activate failed error: %{public}@", error.localizedDescription)
            } else {
                self.initializeObservers()
            }
        }
    }

    deinit {
        manager.invalidate()
    }

    func initializeObservers() {
        updateState()

        stateObservation = manager.observe(\.exposureNotificationStatus, options: [.new]) { [weak self] _, _ in
            self?.updateState()
        }

        enabledObservation = manager.observe(\.exposureNotificationEnabled, options: [.new]) { [weak self] _, _ in
            self?.updateState()
        }
    }

    func updateState() {
        state = .init(state: manager.exposureNotificationStatus,
                      authorizationStatus: ENManager.authorizationStatus,
                      enabled: manager.exposureNotificationEnabled)
    }

    func setEnabled(_ enabled: Bool, completionHandler: ((Error?) -> Void)?) {

        logger.log("calling ENMananger.setExposureNotificationEnabled %@", enabled ? "true" : "false")

        manager.setExposureNotificationEnabled(enabled) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("ENMananger.setExposureNotificationEnabled failed error: %{public}@", error.localizedDescription)
                self.state = .inactive(error: .exposureNotificationError(error: error))
            }
            completionHandler?(error)
        }
    }
}

extension TrackingState {
    init(state: ENStatus, authorizationStatus: ENAuthorizationStatus, enabled: Bool) {
        if authorizationStatus == .unknown {
            self = .stopped
            return
        }

        guard authorizationStatus == .authorized else {
            self = .inactive(error: .permissonError)
            return
        }
        switch state {
        case .active:
            if enabled {
                self = .active
            } else {
                self = .stopped
            }
        case .unknown, .disabled:
            self = .stopped
        case .bluetoothOff:
            self = .inactive(error: .bluetoothTurnedOff)
        case .restricted:
            self = .inactive(error: .permissonError)
        @unknown default:
            fatalError()
        }
    }
}

extension TrackingState: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .active:
            return "active"
        case .stopped:
            return "stopped"
        case let .inactive(error: error):
            return "inactive \(error.localizedDescription)"
        }
    }
}
