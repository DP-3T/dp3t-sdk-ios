/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
#if canImport(ExposureNotification)
import ExposureNotification
#endif

#if canImport(ExposureNotification)
@available(iOS 13.5, *)
class ExposureNotificationTracer: Tracer {
    private let manager: ENManager

    private var stateObservation: NSKeyValueObservation?
    private var enabledObservation: NSKeyValueObservation?

    var delegate: TracerDelegate?

    private(set) var state: TrackingState {
        didSet {
            delegate?.stateDidChange()
        }
    }

    init(manager: ENManager) {
        self.manager = manager

        state = .stopped

        manager.activate { [weak self] _ in
            guard let self = self else { return }
            self.initializeObservers()
        }
    }

    deinit {
        manager.invalidate()
    }

    func initializeObservers() {
        self.updateState()

        self.stateObservation = manager.observe(\.exposureNotificationStatus, options: [.new]) { [weak self] _, _ in
            self?.updateState()
        }

        self.enabledObservation = manager.observe(\.exposureNotificationEnabled, options: [.new]) { [weak self] _, _ in
            self?.updateState()
        }
    }

    func updateState(){
        self.state = .init(state: self.manager.exposureNotificationStatus,
                           authorizationStatus: ENManager.authorizationStatus,
                           enabled: self.manager.exposureNotificationEnabled)
    }


    func setEnabled(_ enabled: Bool) {
        manager.setExposureNotificationEnabled(enabled) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.state = .inactive(error: .exposureNotificationError(error: error))
            }
            self.updateState()
        }
    }
}

@available(iOS 13.5, *)
extension TrackingState {
    init(state: ENStatus, authorizationStatus: ENAuthorizationStatus, enabled: Bool ) {
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
#endif
