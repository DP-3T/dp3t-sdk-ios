/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation

class MockTask: URLSessionDataTask {
    private let data_: Data?
    private let urlResponse_: URLResponse?
    private let error_: Error?

    var internalState: URLSessionTask.State = .suspended

    override var state: URLSessionTask.State {
        internalState
    }

    override func cancel() {
        internalState = .canceling
    }

    var completionHandler: ((Data?, URLResponse?, Error?) -> Void)?

    init(data: Data?, urlResponse: URLResponse?, error: Error?) {
        data_ = data
        urlResponse_ = urlResponse
        error_ = error
    }

    override func resume() {
        internalState = .running
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if self.internalState != .canceling {
                self.internalState = .completed
                self.completionHandler?(self.data_, self.urlResponse_, self.error_)
            }
        }
    }
}

class MockUrlCache: URLCache {
    var response: CachedURLResponse?
    init(response: CachedURLResponse) {
        self.response = response
        super.init(memoryCapacity: 1, diskCapacity: 1, diskPath: "")
    }

    override func cachedResponse(for _: URLRequest) -> CachedURLResponse? {
        return response
    }
}

class MockSession: URLSession {
    var data: Data?
    var urlResponse: URLResponse?
    var error: Error?

    var requests: [URLRequest] = []

    init(data: Data?, urlResponse: URLResponse?, error: Error?) {
        self.data = data
        self.urlResponse = urlResponse
        self.error = error
    }

    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        requests.append(request)
        let task = MockTask(data: data, urlResponse: urlResponse, error: error)
        task.completionHandler = completionHandler
        return task
    }
}
