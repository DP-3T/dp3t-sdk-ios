/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

/// This is used to differentiate between production and calibration mode
public enum DP3TMode: Equatable {

    #if canImport(ExposureNotification)
    @available(iOS 13.4, *)
    case exposureNotificationFramework
    #endif

    @available(iOS, deprecated: 13.4, renamed: "exposureNotificationFramework")
    case customImplementation
    #if CALIBRATION
        @available(iOS, deprecated: 13.4, renamed: "exposureNotificationFramework")
        case customImplementationCalibration(identifierPrefix: String, appVersion: String)
    #endif

    static var current: DP3TMode = .customImplementation
}
