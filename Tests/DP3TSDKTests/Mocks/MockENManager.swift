/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

@testable import DP3TSDK
import Foundation
import ExposureNotification

class MockENManager: ENManager {
    var activateCallbacks: [ENErrorHandler] = []

    var isEnabled = false {
        willSet {
            willChangeValue(for: \.exposureNotificationEnabled)
        }
        didSet {
            didChangeValue(for: \.exposureNotificationEnabled)
        }
    }
    
    var status: ENStatus = .unknown {
        willSet {
            willChangeValue(for: \.exposureNotificationStatus)
        }
        didSet {
            didChangeValue(for: \.exposureNotificationStatus)
        }
    }

    static var authStatus: ENAuthorizationStatus = .unknown

    var detectExposuresWasCalled = false

    var data: [Data] = []

    var summary = MockSummary()

    var enableError: Error?

    override func detectExposures(configuration _: ENExposureConfiguration, diagnosisKeyURLs: [URL], completionHandler: @escaping ENDetectExposuresHandler) -> Progress {
        detectExposuresWasCalled = true
        completionHandler(summary, nil)
        diagnosisKeyURLs.forEach {
            let diagData = try! Data(contentsOf: $0)
            data.append(diagData)
        }
        return Progress()
    }

    var getExposureWindowsWasCalled = false

    var windows: [MockWindow] = []

    override func getExposureWindows(summary: ENExposureDetectionSummary, completionHandler: @escaping ENGetExposureWindowsHandler) -> Progress {
        getExposureWindowsWasCalled = true
        completionHandler(windows, nil)
        return Progress()
    }

    override func activate(completionHandler: @escaping ENErrorHandler) {
        activateCallbacks.append(completionHandler)
    }

    override func setExposureNotificationEnabled(_ enabled: Bool, completionHandler: @escaping ENErrorHandler) {
        if let error = enableError {
            completionHandler(error)
        } else {
            self.isEnabled = enabled
            self.status = .active
            Self.authStatus = .authorized
            completionHandler(nil)
        }
    }

    func completeActivation(error: Error? = nil){
        activateCallbacks.forEach{ $0(error)}
        activateCallbacks.removeAll()
    }

    override var exposureNotificationEnabled: Bool {
        isEnabled
    }

    override var exposureNotificationStatus: ENStatus {
        status
    }

    override class var authorizationStatus: ENAuthorizationStatus {
        Self.authStatus
    }

    var keys: [ENTemporaryExposureKey] = []

    override func getDiagnosisKeys(completionHandler: @escaping ENGetDiagnosisKeysHandler) {
        completionHandler(keys, nil)
    }
}

class MockSummary: ENExposureDetectionSummary {
    override var attenuationDurations: [NSNumber] {
        get {
            internalAttenutationDurations
        }
        set {
            internalAttenutationDurations = newValue
        }
    }

    private var internalAttenutationDurations: [NSNumber] = [0, 0, 0]
}
