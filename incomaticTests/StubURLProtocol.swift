//
//  StubURLProtocol.swift
//  incomaticTests
//
//  Test-only URLProtocol stub. Intercepts every request made through
//  URLSession.shared (which is how all 5 network services in incomatic/ are
//  hard-coded — none take an injected URLSession) so the decode/error paths
//  of those services can be exercised without hitting the network or
//  refactoring production code to add a DI seam.
//

import Foundation

final class StubURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let body: Data?
        /// When set, simulates a transport failure instead of returning a response.
        let transportError: Error?

        init(statusCode: Int, body: Data? = nil, transportError: Error? = nil) {
            self.statusCode = statusCode
            self.body = body
            self.transportError = transportError
        }
    }

    /// Set by each test right before invoking the service call under test.
    static var stub: Stub?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = StubURLProtocol.stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        if let error = stub.transportError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://stub.invalid")!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let body = stub.body {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
