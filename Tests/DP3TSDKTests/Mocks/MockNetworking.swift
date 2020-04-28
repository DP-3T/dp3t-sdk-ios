/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation

class MockTask: URLSessionDataTask {
    private let data_: Data?
    private let urlResponse_: URLResponse?
    private let error_: Error?

    var completionHandler: ((Data?, URLResponse?, Error?) -> Void)?

    init(data: Data?, urlResponse: URLResponse?, error: Error?) {
        data_ = data
        urlResponse_ = urlResponse
        error_ = error
    }

    override func resume() {
        completionHandler?(data_, urlResponse_, error_)
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
    let task: MockTask
    var requests: [URLRequest] = []

    init(data: Data?, urlResponse: URLResponse?, error: Error?) {
        task = MockTask(data: data, urlResponse: urlResponse, error: error)
    }

    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        requests.append(request)
        task.completionHandler = completionHandler
        return task
    }
}
