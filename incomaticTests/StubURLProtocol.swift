//
//  StubURLProtocol.swift
//  incomaticTests
//
//  Test-only URLProtocol stub. All 5 network services route through
//  APISession, so the decode/error paths can be exercised without hitting the
//  network by swapping APISession.session for one whose configuration carries
//  this class.
//
//  `URLProtocol.registerClass` is NOT enough on its own: it only affects
//  URLSession.shared, and a session built from its own configuration reads
//  configuration.protocolClasses instead. Call `install()` / `uninstall()`.
//

import Foundation
@testable import Incomatic

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

extension StubURLProtocol {
    /// Point `APISession` at a session this class can intercept.
    static func install() {
        APISession.session = APISession.makeSession(protocolClasses: [StubURLProtocol.self])
    }

    /// Restore the real session so a later test cannot inherit the stub.
    static func uninstall() {
        stub = nil
        APISession.session = APISession.makeSession()
    }
}
