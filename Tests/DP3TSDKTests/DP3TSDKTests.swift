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

    func setEnabled(_ enabled: Bool, completionHandler: ((Error?) -> Void)?) {
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
    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        completionHandler(.success([]))
    }

    func getFakeKeys(count: Int) -> [CodableDiagnosisKey] {
        return []
    }

    func getDiagnosisKeys(onsetDate: Date?, appDesc: ApplicationDescriptor, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        completionHandler(.success([]))
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

    func addExposeeList(_: ExposeeListModel, authentication _: ExposeeAuthMethod, completion _: @escaping (Result<OutstandingPublish, DP3TNetworkingError>) -> Void) {}

    func addDelayedExposeeList(_: DelayedKeyModel, token _: String?, completion _: @escaping (Result<Void, DP3TNetworkingError>) -> Void) {}
}

class DP3TSDKTests: XCTestCase {

    func testInit(){
        let keychain = MockKeychain()
        let tracer = MockTracer()
        let matcher = MockMatcher()
        let service = MockService()
        let defaults = MockDefaults()
        let keyProvider = MockKeyProvider()
        let descriptor = ApplicationDescriptor(appId: "org.dpppt", bucketBaseUrl: URL(string: "http://google.com")!, reportBaseUrl: URL(string: "http://google.com")!)
        let backgroundTaskManager = DP3TBackgroundTaskManager(handler: nil, keyProvider: keyProvider, serviceClient: service)
        let sdk = DP3TSDK(applicationDescriptor: descriptor,
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
        wait(for: [exp], timeout: 1.0)
    }

}
