/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import Foundation

class MockDefaults: DefaultStorage {
    var parameters: DP3TParameters = .init()

    var outstandingPublishes: Set<OutstandingPublish> = []

    var isFirstLaunch: Bool = false

    var lastSync: Date?

    var lastLoadedBatchReleaseTime: Date?

    var didMarkAsInfected: Bool = false
}
