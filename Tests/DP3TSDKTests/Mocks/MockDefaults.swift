/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
@testable import DP3TSDK

class MockDefaults: DefaultStorage {
    var isFirstLaunch: Bool = false

    var lastSync: Date? = nil

    var lastLoadedBatchReleaseTime: Date? = nil

    var didMarkAsInfected: Bool = false
}
