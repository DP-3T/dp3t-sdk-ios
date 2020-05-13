/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation

public enum DP3TMode {
    /// should be used in production
    case production
    #if CALIBRATION
    /// stores logs in sqlite
    case calibration
    #endif

    static var current: DP3TMode = .production
}
