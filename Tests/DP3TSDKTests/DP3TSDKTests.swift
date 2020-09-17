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
import XCTest

private class MockKeyProvider: DiagnosisKeysProvider {

    var keys = [CodableDiagnosisKey]()
    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        completionHandler(.success(keys.filter { $0.fake == 1 }))
    }

    func getDiagnosisKeys(onsetDate: Date?, appDesc: ApplicationDescriptor, disableExposureNotificationAfterCompletion: Bool, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        completionHandler(.success(keys.filter { $0.fake == 0 }))
    }
}


class DP3TSDKTests: XCTestCase {
    fileprivate struct SDK {
        fileprivate var keychain: MockKeychain!
        fileprivate var tracer: ExposureNotificationTracer!
        fileprivate var matcher: ExposureNotificationMatcher!
        fileprivate var service: MockService!
        fileprivate var defaults: MockDefaults!
        fileprivate var keyProvider: MockKeyProvider!
        var descriptor: ApplicationDescriptor {
            MockService.descriptor
        }
        fileprivate var backgroundTaskManager: DP3TBackgroundTaskManager!
        fileprivate var manager: MockENManager!
        fileprivate var exposureDayStorage: ExposureDayStorage!
        fileprivate var outstandingPublishStorage: OutstandingPublishStorage!
        fileprivate var sdk: DP3TSDK!
        init() {
            keychain = MockKeychain()
            manager = MockENManager()
            exposureDayStorage = ExposureDayStorage(keychain: keychain)
            defaults = MockDefaults()
            tracer = ExposureNotificationTracer(manager: manager, managerClass: MockENManager.self)
            matcher = ExposureNotificationMatcher(manager: manager, exposureDayStorage: exposureDayStorage, defaults: defaults)
            service = MockService()
            keyProvider = MockKeyProvider()
            backgroundTaskManager = DP3TBackgroundTaskManager(handler: nil, keyProvider: keyProvider, serviceClient: service, tracer: tracer)
            outstandingPublishStorage = OutstandingPublishStorage(keychain: keychain)
            sdk = DP3TSDK(applicationDescriptor: descriptor,
                              urlSession: MockSession(data: nil, urlResponse: nil, error: nil),
                              tracer: tracer,
                              matcher: matcher,
                              diagnosisKeysProvider: keyProvider,
                              exposureDayStorage: exposureDayStorage,
                              outstandingPublishesStorage: outstandingPublishStorage,
                              service: service,
                              synchronizer: KnownCasesSynchronizer(matcher: matcher, service: service, defaults: defaults, descriptor: descriptor),
                              backgroundTaskManager: backgroundTaskManager,
                              defaults: defaults)
        }
    }

    func testInitialStatus(){
        let sdk = SDK()
        let exp = expectation(description: "status")
        sdk.sdk.status { (result) in
            switch result {
            case .failure(_):
                XCTFail()
            case let .success(state):
                XCTAssert(state.trackingState == .initialization)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testCallEnable(){
        let sdk = SDK()
        sdk.manager.completeActivation()
        let exp = expectation(description: "enable")
        try! sdk.sdk.startTracing { (err) in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(sdk.tracer.state, TrackingState.active)
    }

    func testInfected(){
        let sdk = SDK()
        let stateexp = expectation(description: "stateBefore")
        sdk.sdk.status { (result) in
            switch result {
            case .failure(_):
                XCTFail()
            case let .success(state):
                switch state.infectionStatus {
                case .healthy:
                    break;
                default:
                    XCTFail()
                }
            }
            stateexp.fulfill()
        }
        wait(for: [stateexp], timeout: 1.0)

        let exp = expectation(description: "infected")
        sdk.keyProvider.keys = [ .init(keyData: Data(count: 16), rollingPeriod: 144, rollingStartNumber: DayDate().period, transmissionRiskLevel: 0, fake: 0) ]
        sdk.sdk.iWasExposed(onset: .init(timeIntervalSinceNow: -.day), authentication: .none) { (result) in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        let model = sdk.service.exposeeListModel

        XCTAssertEqual(sdk.outstandingPublishStorage.get().count, 1)

        if #available(iOS 13.7, *) {
            XCTAssertFalse(sdk.defaults.infectionStatusIsResettable)
        }
        XCTAssert(model != nil)
        XCTAssertEqual(model!.gaenKeys.count, sdk.defaults.parameters.crypto.numberOfKeysToSubmit)
        let rollingStartNumbers = Set(model!.gaenKeys.map(\.rollingStartNumber))
        XCTAssertEqual(rollingStartNumbers.count, model!.gaenKeys.count)
        var runningDate: Date?
        for key in model!.gaenKeys {
            let date = Date(timeIntervalSince1970: Double(key.rollingStartNumber) * 10 * .minute)
            guard runningDate != nil else {
                runningDate = date
                continue
            }
            let timeDiff = runningDate?.timeIntervalSince(date)
            XCTAssertEqual(timeDiff, .day)
            runningDate = date
        }

        let stateExpAfter = expectation(description: "stateAfter")
        sdk.sdk.status { (result) in
            switch result {
            case .failure(_):
                XCTFail()
            case let .success(state):
                switch state.infectionStatus {
                case .infected:
                    break;
                default:
                    XCTFail()
                }
                if #available(iOS 13.7, *) {
                    XCTAssertNotEqual(state.trackingState, .stopped)
                } else {
                    XCTAssertEqual(state.trackingState, .stopped)
                }
            }
            stateExpAfter.fulfill()
        }
        wait(for: [stateExpAfter], timeout: 1.0)


        XCTAssertThrowsError(try sdk.sdk.startTracing())
    }

    func testSyncDontCompleteBeforeInit(){
        let sdk = SDK()
        let exp = expectation(description: "sync")
        exp.isInverted = true
        sdk.sdk.sync(runningInBackground: false) { (result) in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testSyncCompleteAfterInit(){
        let sdk = SDK()
        let exp = expectation(description: "sync")
        sdk.sdk.sync(runningInBackground: false) { (result) in
            exp.fulfill()
        }
        sdk.manager.completeActivation()
        wait(for: [exp], timeout: 1.0)
    }

    func testSyncWhenActive(){
        let sdk = SDK()
        let exp = expectation(description: "sync")
        sdk.sdk.sync(runningInBackground: false) { (result) in
            exp.fulfill()
        }
        sdk.manager.status = .active
        MockENManager.authStatus = .authorized
        sdk.manager.isEnabled = true
        sdk.manager.completeActivation()
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sdk.service.requests.count, 10)
    }

    struct MockError: Error, Equatable {
        let message: String
    }

    func testActivationAfterFailure() {
        let sdk = SDK()
        MockENManager.authStatus = .unknown
        let message = "mockError"
        sdk.manager.completeActivation(error:  MockError(message: message))
        sleep(1)
        let expStatus = expectation(description: "status")
        sdk.sdk.status { (result) in
            switch result {
            case let .success(state):
                switch state.trackingState {
                case let .inactive(error: error):
                    switch error {
                    case let .exposureNotificationError(error: enError):
                        guard let mockError = enError as? MockError else {
                            XCTFail()
                            return
                        }
                        XCTAssertEqual(mockError.message, message)
                    default:
                        XCTFail()
                    }
                default:
                    XCTFail()
                }
            case .failure(_):
                XCTFail()
            }
            expStatus.fulfill()
        }
        wait(for: [expStatus], timeout: 1.0)


        // app comes again in foreground
        sdk.tracer.willEnterForeground()
        sleep(1)

        MockENManager.authStatus = .authorized
        sdk.manager.completeActivation()
        sleep(1)

        let expStatusAfter = expectation(description: "statusafter")
        sdk.sdk.status { (result) in
            switch result {
            case let .success(state):
                switch state.trackingState {
                case .stopped:
                    break;
                default:
                    XCTFail()
                }
            case .failure(_):
                XCTFail()
            }
            expStatusAfter.fulfill()
        }
        wait(for: [expStatusAfter], timeout: 1.0)
    }

    func testEnableAfterEnableFailure(){
        let sdk = SDK()
        sdk.manager.enableError = MockError(message: "message")
        sdk.manager.isEnabled = true
        sdk.manager.completeActivation()
        let exp = expectation(description: "enable")
        try! sdk.sdk.startTracing { (err) in
            XCTAssert(err != nil)
            XCTAssertEqual((err! as! MockError).message, "message")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sdk.tracer.state, TrackingState.inactive(error: .exposureNotificationError(error: sdk.manager.enableError!)))

        sdk.manager.enableError = nil

        // app comes again in foreground
        sdk.tracer.willEnterForeground()

       sleep(1)

        XCTAssertEqual(sdk.tracer.state, TrackingState.active)
    }

    func testEnableAfterActivationFailure(){
        let sdk = SDK()
        MockENManager.authStatus = .unknown
        let error = MockError(message: "mockError")

        sdk.manager.completeActivation(error: error)
        sleep(1)
        let exp = expectation(description: "enable")
        try! sdk.sdk.startTracing { (err) in
            XCTAssert(err != nil)
            switch (err! as! DP3TTracingError) {
            case let .exposureNotificationError(error: enError):
                XCTAssertEqual(enError as! MockError, error)
            default:
                XCTFail()
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(sdk.tracer.state, TrackingState.inactive(error: .exposureNotificationError(error: error)))


        // app comes again in foreground
        sdk.tracer.willEnterForeground()

        sleep(1)

        sdk.manager.completeActivation()

        sleep(1)

        XCTAssertEqual(sdk.tracer.state, TrackingState.active)
    }
}
