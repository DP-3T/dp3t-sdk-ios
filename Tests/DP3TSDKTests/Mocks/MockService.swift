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


    static var descriptor: ApplicationDescriptor = .init(appId: "org.dpppt", bucketBaseUrl: URL(string: "https://bucket.dpppt.org")!, reportBaseUrl: URL(string: "https://report.bucket.dpppt.org")!)

    var descriptor: ApplicationDescriptor {
        Self.descriptor
    }

    var requests: [Int64?] = []
    let session = MockSession(data: "Data".data(using: .utf8), urlResponse: nil, error: nil)
    let queue = DispatchQueue(label: "synchronous")
    var error: DP3TNetworkingError?
    var keyBundleTag: Int64? = nil
    var data: Data? = "Data".data(using: .utf8)
    var errorAfter: Int = 0

    func getExposee(lastKeyBundleTag: Int64?, includeInternationalKeys: Bool, completion: @escaping (Result<ExposeeSuccess, DP3TNetworkingError>) -> Void) -> URLSessionDataTask {
        return session.dataTask(with: .init(url: URL(string: "http://www.google.com")!)) { _, _, _ in
            self.queue.sync {
                self.requests.append(lastKeyBundleTag)
            }
            
            if let error = self.error, self.errorAfter <= 0 {
                completion(.failure(error))
            } else {
                self.errorAfter -= 1
                completion(.success(.init(data: self.data, keyBundleTag: self.keyBundleTag)))
            }
        }
    }

    var exposeeListModel: ExposeeListModel?

    func addExposeeList(_ model: ExposeeListModel, authentication _: ExposeeAuthMethod, completion: @escaping (Result<Void, DP3TNetworkingError>) -> Void) {
        exposeeListModel = model
        completion(.success(()))
    }
}
