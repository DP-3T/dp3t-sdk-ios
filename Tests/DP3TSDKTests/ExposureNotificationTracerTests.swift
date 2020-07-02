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

class ExposureNotificationTracerTests: XCTestCase {

    var manager: MockENManager!
    var tracer: ExposureNotificationTracer!

    override func setUp() {
        self.manager = MockENManager()
        self.tracer = ExposureNotificationTracer(manager: manager, managerClass: MockENManager.self)
    }

    func testCallingCallbacks() {
        let ex = expectation(description: "init")
        tracer.addInitialisationCallback {
            ex.fulfill()
        }
        manager.completeActivation()
        wait(for: [ex], timeout: 1)
    }

    func testCallingCallbacksAfterActivate() {
        let ex = expectation(description: "init")
        tracer.addInitialisationCallback {
            ex.fulfill()
        }
        manager.completeActivation()
        wait(for: [ex], timeout: 1)

        let ex1 = expectation(description: "afterInit")
        tracer.addInitialisationCallback {
            ex1.fulfill()
        }
        wait(for: [ex1], timeout: 1)
    }

    func testStatusActive(){
        manager.status = .active
        MockENManager.authStatus = .authorized
        manager.isEnabled = true

        let ex = expectation(description: "init")
        tracer.addInitialisationCallback {
            XCTAssertEqual(self.tracer.state, TrackingState.active)

            ex.fulfill()
        }
        manager.completeActivation()
        wait(for: [ex], timeout: 1)
    }

    func testStatusStopped(){
        manager.status = .active
        MockENManager.authStatus = .authorized
        manager.isEnabled = false

        let ex = expectation(description: "init")
        tracer.addInitialisationCallback {
            XCTAssertEqual(self.tracer.state, TrackingState.stopped)

            ex.fulfill()
        }
        manager.completeActivation()
        wait(for: [ex], timeout: 1)
    }

    func testStatusInctiveBluetoothOff(){
        manager.status = .bluetoothOff
        MockENManager.authStatus = .authorized
        manager.isEnabled = false

        let ex = expectation(description: "init")
        tracer.addInitialisationCallback {
            XCTAssertEqual(self.tracer.state, TrackingState.inactive(error: .bluetoothTurnedOff))

            ex.fulfill()
        }
        manager.completeActivation()
        wait(for: [ex], timeout: 1)
    }

    func testStatusPermission(){
        manager.status = .restricted
        MockENManager.authStatus = .authorized
        manager.isEnabled = false

        let ex = expectation(description: "init")
        tracer.addInitialisationCallback {
            XCTAssertEqual(self.tracer.state, TrackingState.inactive(error: .permissonError))

            ex.fulfill()
        }
        manager.completeActivation()
        wait(for: [ex], timeout: 1)
    }

    func testStatusInitialisation(){
        XCTAssertEqual(tracer.state, TrackingState.initialization)
    }

    func testKVOStatusUpdate(){
        manager.status = .restricted
        MockENManager.authStatus = .authorized
        manager.isEnabled = false

        let ex = expectation(description: "init")
        tracer.addInitialisationCallback {
            
            XCTAssertEqual(self.tracer.state, TrackingState.inactive(error: .permissonError))

            self.manager.status = .active
            self.manager.isEnabled = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(self.tracer.state, TrackingState.active)
                ex.fulfill()
            }
        }
        manager.completeActivation()
        wait(for: [ex], timeout: 1)
    }
}
