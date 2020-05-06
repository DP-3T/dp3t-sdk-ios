/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/


import Foundation
#if canImport(ExposureNotification)
import ExposureNotification
#endif

@available(iOS 13.4, *)
class ExposureNotificationTracer: Tracer {

    private let manager: ENManager

    private var observation: NSKeyValueObservation?

    init(manager: ENManager) {
        self.manager = manager

        self.state = .init(state: manager.exposureNotificationStatus)

        observation = manager.observe(\.exposureNotificationStatus, options: [.new] ) { [weak self] _, change in
            guard let self = self,
                  let newState = change.newValue else { return }
            self.state = .init(state: newState)
        }
    }

    var delegate: TracerDelegate?

    private(set) var state: TrackingState {
        didSet {
            delegate?.stateDidChange()
        }
    }

    func setEnabled(_ enabled: Bool) {
        manager.setExposureNotificationEnabled(enabled) { [weak self] (error) in
            guard let self = self else { return }
            if let error = error {
                self.state = .inactive(error: .exposureNotificationError(error: error))
            } else {
                self.state = enabled ? .active : .stopped
            }
        }
    }
}

@available(iOS 13.4, *)
extension TrackingState {
    init(state: ENStatus) {
        switch state {
        case .active:
            self = .active
        case .bluetoothOff:
            self = .inactive(error: .bluetoothTurnedOff)
        case .disabled, .restricted, .unknown:
            self = .inactive(error: .permissonError)
        @unknown default:
            fatalError()
        }
    }
}
