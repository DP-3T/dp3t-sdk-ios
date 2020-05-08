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

        private var observation: NSKeyValueObservation?

        init(manager: ENManager) {
            self.manager = manager

            state = .init(state: manager.exposureNotificationStatus)

            manager.activate { [weak self] _ in
                guard let self = self else { return }

                self.observation = manager.observe(\.exposureNotificationStatus, options: [.new]) { [weak self] _, change in
                    guard let self = self,
                        let newState = change.newValue else { return }
                    self.state = .init(state: newState)
                }
            }
        }

        deinit {
            manager.invalidate()
        }

        var delegate: TracerDelegate?

        private(set) var state: TrackingState {
            didSet {
                delegate?.stateDidChange()
            }
        }

        func setEnabled(_ enabled: Bool) {
            manager.setExposureNotificationEnabled(enabled) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.state = .inactive(error: .exposureNotificationError(error: error))
                } else {
                    self.state = enabled ? .active : .stopped
                }
            }
        }
    }

    @available(iOS 13.5, *)
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
#endif
