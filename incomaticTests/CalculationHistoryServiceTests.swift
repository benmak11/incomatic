//
//  CalculationHistoryServiceTests.swift
//  incomaticTests
//
//  CalculationHistoryService also hard-codes URLSession.shared — same
//  StubURLProtocol seam as the other service tests. Covers the pre-flight
//  no-token path and the 401 handling added to match the documented
//  "/v1/calculations is 401-when-anonymous" contract (previously fell through
//  to the generic .server(401, msg) case here, unlike Equity/BudgetService).
//

import XCTest
@testable import Incomatic

final class CalculationHistoryServiceTests: XCTestCase {

    private var service: CalculationHistoryService!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
        service = CalculationHistoryService()
    }

    override func tearDown() {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        StubURLProtocol.stub = nil
        service = nil
        super.tearDown()
    }

    func test_noSessionToken_throwsNotAuthenticatedWithoutHittingNetwork() async {
        service.sessionTokenProvider = { nil }

        do {
            _ = try await service.list()
            XCTFail("expected notAuthenticated")
        } catch CalculationHistoryService.HistoryError.notAuthenticated {
            // expected
        } catch {
            XCTFail("expected HistoryError.notAuthenticated, got \(error)")
        }
    }

    func test_list_401_throwsNotAuthenticated() async {
        service.sessionTokenProvider = { "expired-token" }
        StubURLProtocol.stub = .init(statusCode: 401, body: "unauthorized".data(using: .utf8))

        do {
            _ = try await service.list()
            XCTFail("expected notAuthenticated")
        } catch CalculationHistoryService.HistoryError.notAuthenticated {
            // expected
        } catch {
            XCTFail("expected HistoryError.notAuthenticated, got \(error)")
        }
    }

    func test_list_malformedJSON_throwsDecodingError() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 200, body: "not json".data(using: .utf8))

        do {
            _ = try await service.list()
            XCTFail("expected decoding error")
        } catch CalculationHistoryService.HistoryError.decoding {
            // expected
        } catch {
            XCTFail("expected HistoryError.decoding, got \(error)")
        }
    }

    func test_get_serverErrorStatus_throwsServerErrorWithCodeAndBody() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 500, body: "boom".data(using: .utf8))

        do {
            _ = try await service.get(id: "abc123")
            XCTFail("expected serverError")
        } catch CalculationHistoryService.HistoryError.server(let code, let message) {
            XCTAssertEqual(code, 500)
            XCTAssertEqual(message, "boom")
        } catch {
            XCTFail("expected HistoryError.server, got \(error)")
        }
    }

    func test_delete_transportFailure_throwsNetworkError() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 0, transportError: URLError(.networkConnectionLost))

        do {
            try await service.delete(id: "abc123")
            XCTFail("expected network error")
        } catch CalculationHistoryService.HistoryError.network {
            // expected
        } catch {
            XCTFail("expected HistoryError.network, got \(error)")
        }
    }
}
