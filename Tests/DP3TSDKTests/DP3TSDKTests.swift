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

private class MockTracer: Tracer {
    var delegate: TracerDelegate?

    var state: TrackingState = .active

    var isEnabled = false

    func setEnabled(_ enabled: Bool, completionHandler: ((Error?) -> Void)?) {
        isEnabled = enabled
        completionHandler?(nil)
    }
}

private class MockMatcher: Matcher {
    var timingManager: ExposureDetectionTimingManager?

    var delegate: MatcherDelegate?

    func receivedNewKnownCaseData(_ data: Data, keyDate: Date) throws {}

    func finalizeMatchingSession(now: Date) throws {}
}

private class MockKeyProvider: DiagnosisKeysProvider {
    var keys = [CodableDiagnosisKey]()
    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        completionHandler(.success(keys.filter { $0.fake == 1 }))
    }

    func getDiagnosisKeys(onsetDate: Date?, appDesc: ApplicationDescriptor, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        completionHandler(.success(keys.filter { $0.fake == 0 }))
    }
}

private class MockService: ExposeeServiceClientProtocol {

    var descriptor: ApplicationDescriptor = .init(appId: "org.dpppt", bucketBaseUrl: URL(string: "http://google.com")!, reportBaseUrl: URL(string: "http://google.com")!)

    var requests: [Date] = []
    let session = MockSession(data: "Data".data(using: .utf8), urlResponse: nil, error: nil)
    let queue = DispatchQueue(label: "synchronous")
    var error: DP3TNetworkingError?
    var publishedUntil: Date = .init()
    var data: Data? = "Data".data(using: .utf8)

    func getExposee(batchTimestamp: Date, completion: @escaping (Result<ExposeeSuccess, DP3TNetworkingError>) -> Void) -> URLSessionDataTask {
        return session.dataTask(with: .init(url: URL(string: "http://www.google.com")!)) { _, _, _ in
            if let error = self.error {
                completion(.failure(error))
            } else {
                self.queue.sync {
                    self.requests.append(batchTimestamp)
                }
                completion(.success(.init(data: self.data, publishedUntil: self.publishedUntil)))
            }
        }
    }

    var exposeeListModel: ExposeeListModel?

    func addExposeeList(_ model: ExposeeListModel, authentication _: ExposeeAuthMethod, completion: @escaping (Result<OutstandingPublish, DP3TNetworkingError>) -> Void) {
        exposeeListModel = model
        completion(.success(.init(authorizationHeader: "xy", dayToPublish: .init(), fake: model.fake)))
    }

    func addDelayedExposeeList(_: DelayedKeyModel, token _: String?, completion _: @escaping (Result<Void, DP3TNetworkingError>) -> Void) {}
}

class DP3TSDKTests: XCTestCase {

    fileprivate var keychain: MockKeychain!
    fileprivate var tracer: MockTracer!
    fileprivate var matcher: MockMatcher!
    fileprivate var service: MockService!
    fileprivate var defaults: MockDefaults!
    fileprivate var keyProvider: MockKeyProvider!
    fileprivate var descriptor: ApplicationDescriptor!
    fileprivate var backgroundTaskManager: DP3TBackgroundTaskManager!
    fileprivate var sdk: DP3TSDK!

    override func setUp() {
        keychain = MockKeychain()
        tracer = MockTracer()
        matcher = MockMatcher()
        service = MockService()
        defaults = MockDefaults()
        keyProvider = MockKeyProvider()
        descriptor = ApplicationDescriptor(appId: "org.dpppt", bucketBaseUrl: URL(string: "http://google.com")!, reportBaseUrl: URL(string: "http://google.com")!)
        backgroundTaskManager = DP3TBackgroundTaskManager(handler: nil, keyProvider: keyProvider, serviceClient: service)
        sdk = DP3TSDK(applicationDescriptor: descriptor,
                          urlSession: MockSession(data: nil, urlResponse: nil, error: nil),
                          tracer: tracer,
                          matcher: matcher,
                          diagnosisKeysProvider: keyProvider,
                          exposureDayStorage: ExposureDayStorage(keychain: keychain),
                          outstandingPublishesStorage: OutstandingPublishStorage(keychain: keychain),
                          service: service,
                          synchronizer: KnownCasesSynchronizer(matcher: matcher, service: service, defaults: defaults, descriptor: descriptor),
                          backgroundTaskManager: backgroundTaskManager,
                          defaults: defaults)
    }

    func testInitialStatus(){
        let exp = expectation(description: "status")
        sdk.status { (result) in
            switch result {
            case .failure(_):
                XCTFail()
            case let .success(state):
                XCTAssert(state.trackingState == .stopped)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 0.1)
    }

    func testCallEnable(){
        let exp = expectation(description: "enable")
        try! sdk.startTracing { (err) in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 0.1)
        XCTAssert(tracer.isEnabled)
    }

    func testInfected(){

        let stateexp = expectation(description: "stateBefore")
        sdk.status { (result) in
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
        wait(for: [stateexp], timeout: 0.1)

        let exp = expectation(description: "infected")
        keyProvider.keys = [ .init(keyData: Data(count: 16), rollingPeriod: 144, rollingStartNumber: DayDate().period, transmissionRiskLevel: 0, fake: 0) ]
        sdk.iWasExposed(onset: .init(timeIntervalSinceNow: -.day), authentication: .none) { (result) in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 0.1)
        let model = service.exposeeListModel
        XCTAssert(model != nil)
        XCTAssertEqual(model!.gaenKeys.count, defaults.parameters.crypto.numberOfKeysToSubmit)
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
        sdk.status { (result) in
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
            }
            stateExpAfter.fulfill()
        }
        wait(for: [stateExpAfter], timeout: 0.1)

        XCTAssertThrowsError(try sdk.startTracing())
    }
}
