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
    self.data_ = data
    self.urlResponse_ = urlResponse
    self.error_ = error
  }

  override func resume() {
    DispatchQueue.main.async {
        self.completionHandler?(self.data_, self.urlResponse_, self.error_)
    }
  }
}

class MockUrlCache: URLCache {
    var response: CachedURLResponse?
    init(response: CachedURLResponse) {
        self.response = response
        super.init(memoryCapacity: 1, diskCapacity: 1, diskPath: "")
    }
    override func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
        return response
    }
}

class MockSession: URLSession {
    let task: MockTask
    var request_: URLRequest?

    init(data: Data?, urlResponse: URLResponse?, error: Error?) {
        task = MockTask(data: data, urlResponse: urlResponse, error: error)
    }
    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        request_ = request
        task.completionHandler = completionHandler
        return task
    }
}
