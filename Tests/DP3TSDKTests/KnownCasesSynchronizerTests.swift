/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

@testable import DP3TSDK
import XCTest
import SQLite

fileprivate class MockMatcher: DP3TMatcherProtocol {
    var knownCaseKeys: [Data] = []
    func checkNewKnownCase(_ knownCase: KnownCaseModel) throws {
        knownCaseKeys.append(knownCase.key)
    }
}

final class KnownCasesSynchronizerTests: XCTestCase {

    let connection = try! Connection(.inMemory, readonly: false)

    lazy var database: DP3TDatabase! = try! DP3TDatabase(connection_: connection)

    override func tearDown() {
        try! database.emptyStorage()
    }

    func getMockService(array: [KnownCaseModel] = [], date: Date = Date()) -> (ExposeeServiceClient, MockSession){
        var list = ProtoExposedList()
        list.exposed = array.map {
            var exposee = ProtoExposee()
            exposee.key = $0.key
            exposee.keyDate = $0.onset.millisecondsSince1970
            return exposee
        }
        let data = try! list.serializedData()
        let headers = ["Etag": "HASH", "date": HTTPURLResponse.dateFormatter.string(from: date)]
        let response = HTTPURLResponse(url: URL(string: "http://xy.ch")!, statusCode: 200, httpVersion: nil, headerFields: headers)
        let session = MockSession(data: data, urlResponse: response, error: nil)
        let applicationDescriptor = ApplicationDescriptor(appId: "ch.xy", description: "XY", jwtPublicKey: nil, bucketBaseUrl: URL(string: "http://xy.ch")!, reportBaseUrl: URL(string: "http://xy.ch")!, contact: "xy")
        return (ExposeeServiceClient(descriptor: applicationDescriptor, urlSession: session), session)
    }

    func testFirstLaunchNoRequests() {

        let defaults = MockDefaults()
        let matcher = MockMatcher()
        let (service, session) = getMockService()
        let appInfo = DP3TApplicationInfo.discovery("ch.xy", enviroment: .dev)
        let synchronizer = KnownCasesSynchronizer(appInfo: appInfo,
                                                  database: database,
                                                  matcher: matcher,
                                                  defaults: defaults)
        let exposeeExpectation = expectation(description: "exposee")

        synchronizer.sync(service: service) { (result) in
            if case .success = result {
                XCTAssertEqual(session.requests, [])
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }

    }

    func testNotFirstLaunch() {

        let defaults = MockDefaults()
        defaults.lastLoadedBatchReleaseTime = Date().addingTimeInterval(NetworkingConstants.batchLenght * 100 * (-1))
        let matcher = MockMatcher()
        let (service, session) = getMockService()
        let appInfo = DP3TApplicationInfo.discovery("ch.xy", enviroment: .dev)
        let synchronizer = KnownCasesSynchronizer(appInfo: appInfo,
                                                  database: database,
                                                  matcher: matcher,
                                                  defaults: defaults)
        let exposeeExpectation = expectation(description: "exposee")

        synchronizer.sync(service: service) { (result) in
            if case .success = result {
                XCTAssertEqual(session.requests.count, 100)
            } else {
                XCTFail()
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }

    }

    func testCallingOfMatcher(){
        let b64Key = "k6zymVXKbPHBkae6ng2k3H25WrpqxUEluI1w86t+eOI="
        let key = Data(base64Encoded: b64Key)!
        let defaults = MockDefaults()
        let now = Date().timeIntervalSince1970
        let ts = now - now.truncatingRemainder(dividingBy: NetworkingConstants.batchLenght)
        defaults.lastLoadedBatchReleaseTime = Date(timeIntervalSince1970: ts - NetworkingConstants.batchLenght)
        let matcher = MockMatcher()
        let knownCase = KnownCaseModel(id: nil, key: key, onset: Date(), batchTimestamp: Date())
        let (service, _) = getMockService(array: [knownCase])
        let appInfo = DP3TApplicationInfo.discovery("ch.xy", enviroment: .dev)
        let synchronizer = KnownCasesSynchronizer(appInfo: appInfo,
                                                  database: database,
                                                  matcher: matcher,
                                                  defaults: defaults)
        let exposeeExpectation = expectation(description: "exposee")
        synchronizer.sync(service: service) { (result) in

            if case .success = result {
                XCTAssertEqual(matcher.knownCaseKeys.count, 1)
                XCTAssert(matcher.knownCaseKeys.contains(key))
                XCTAssertEqual(try! self.database.knownCasesStorage.getId(for: key), 1)
            } else {
                XCTFail()
            }

            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }
    }

    func testTimeIncosistencyForeward(){

        let defaults = MockDefaults()
        let now = Date().timeIntervalSince1970
        let ts = now - now.truncatingRemainder(dividingBy: NetworkingConstants.batchLenght)
        defaults.lastLoadedBatchReleaseTime = Date(timeIntervalSince1970: ts - NetworkingConstants.batchLenght)
        
        let matcher = MockMatcher()
        let timestamp = Date().addingTimeInterval(NetworkingConstants.timeShiftThreshold * (-1))
        let (service, _) = getMockService(date: timestamp)
        let appInfo = DP3TApplicationInfo.discovery("ch.xy", enviroment: .dev)
        let synchronizer = KnownCasesSynchronizer(appInfo: appInfo,
                                                  database: database,
                                                  matcher: matcher,
                                                  defaults: defaults)
        let exposeeExpectation = expectation(description: "exposee")
        synchronizer.sync(service: service) { (result) in
            switch result {
            case .success:
                XCTFail("Should not succeed due to timeInconsistency")
            case let .failure(error):
                switch error {
                case let .timeInconsistency(shift: shift):
                    let shiftNow = Date().timeIntervalSince(timestamp)
                    XCTAssertEqual(shiftNow, shift, accuracy: .second)
                default:
                    XCTFail("wrong error")
                }
            }
            exposeeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1) { (error) in
          XCTAssertNotNil(exposeeExpectation)
        }
    }

    static var allTests = [
        ("testFirstLaunchNoRequests", testFirstLaunchNoRequests),
        ("testNotFirstLaunch", testNotFirstLaunch),
        ("testCallingOfMatcher", testCallingOfMatcher),
        ("testTimeIncosistencyForeward", testTimeIncosistencyForeward)
    ]
}
