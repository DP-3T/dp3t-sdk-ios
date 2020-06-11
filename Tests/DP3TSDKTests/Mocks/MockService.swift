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

class MockService: ExposeeServiceClientProtocol {

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
