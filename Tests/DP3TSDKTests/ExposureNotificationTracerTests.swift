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
import XCTest
import ExposureNotification

class ExposureNotificationTracerTests: XCTestCase {
    func testCallingCallbacks() {
        let manager = ENManager()
        let tracer = ExposureNotificationTracer(manager: manager)
        let ex = expectation(description: "init")
        tracer.addInitialisationCallback {
            ex.fulfill()
        }
        wait(for: [ex], timeout: 1)
    }
}
