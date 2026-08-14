//
//  AuthServiceTests.swift
//  incomaticTests
//
//  AuthService also hard-codes URLSession.shared — same StubURLProtocol seam
//  as the other service tests. Covers the decode/network paths plus the 401
//  handling added to bring AuthError in line with EquityError/
//  BudgetServiceError/HistoryError (all four now map a 401 response to a
//  dedicated "not authenticated" case instead of the generic server(code,msg)).
//

import XCTest
@testable import Incomatic

final class AuthServiceTests: XCTestCase {

    private var service: AuthService!

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        service = AuthService()
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubURLProtocol.stub = nil
        service = nil
        super.tearDown()
    }

    func test_signInWithApple_malformedJSON_throwsDecodingError() async {
        StubURLProtocol.stub = .init(statusCode: 200, body: "not json".data(using: .utf8))

        do {
            _ = try await service.signInWithApple(identityToken: "tok", nonce: "nonce", displayName: nil)
            XCTFail("expected decoding error")
        } catch AuthService.AuthError.decoding {
            // expected
        } catch {
            XCTFail("expected AuthError.decoding, got \(error)")
        }
    }

    func test_signInWithApple_401_throwsNotAuthenticated() async {
        StubURLProtocol.stub = .init(statusCode: 401, body: "invalid identity token".data(using: .utf8))

        do {
            _ = try await service.signInWithApple(identityToken: "bad-token", nonce: "nonce", displayName: nil)
            XCTFail("expected notAuthenticated")
        } catch AuthService.AuthError.notAuthenticated {
            // expected
        } catch {
            XCTFail("expected AuthError.notAuthenticated, got \(error)")
        }
    }

    func test_signInWithApple_429_throwsRateLimited() async {
        StubURLProtocol.stub = .init(
            statusCode: 429,
            body: "{\"error\":\"Too many requests. Retry in a minute.\"}".data(using: .utf8)
        )

        do {
            _ = try await service.signInWithApple(identityToken: "tok", nonce: "nonce", displayName: nil)
            XCTFail("expected rateLimited")
        } catch AuthService.AuthError.rateLimited {
            // Not server(429, body) — "Sign-in failed (HTTP 429): {json}" is not a
            // message anyone can act on.
        } catch {
            XCTFail("expected AuthError.rateLimited, got \(error)")
        }
    }

    func test_signInWithApple_serverErrorStatus_throwsServerErrorWithBody() async {
        StubURLProtocol.stub = .init(statusCode: 500, body: "boom".data(using: .utf8))

        do {
            _ = try await service.signInWithApple(identityToken: "tok", nonce: "nonce", displayName: nil)
            XCTFail("expected serverError")
        } catch AuthService.AuthError.server(let code, let message) {
            XCTAssertEqual(code, 500)
            XCTAssertEqual(message, "boom")
        } catch {
            XCTFail("expected AuthError.server, got \(error)")
        }
    }

    func test_deleteAccount_401_throwsNotAuthenticated() async {
        StubURLProtocol.stub = .init(statusCode: 401, body: "expired".data(using: .utf8))

        do {
            try await service.deleteAccount(token: "expired-token")
            XCTFail("expected notAuthenticated")
        } catch AuthService.AuthError.notAuthenticated {
            // expected
        } catch {
            XCTFail("expected AuthError.notAuthenticated, got \(error)")
        }
    }

    func test_deleteAccount_transportFailure_throwsNetworkError() async {
        StubURLProtocol.stub = .init(statusCode: 0, transportError: URLError(.notConnectedToInternet))

        do {
            try await service.deleteAccount(token: "token")
            XCTFail("expected network error")
        } catch AuthService.AuthError.network {
            // expected
        } catch {
            XCTFail("expected AuthError.network, got \(error)")
        }
    }
}
