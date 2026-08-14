//
//  BudgetServiceTests.swift
//  incomaticTests
//
//  BudgetService also hard-codes URLSession.shared — same StubURLProtocol
//  seam as the other service tests. Covers the documented status-code
//  contracts: GET 404 -> notFound ("start empty", not a failure), 401 ->
//  notAuthenticated, POST /v1/budget/plan 503 -> planUnavailable (Vertex AI
//  unconfigured/failed), and that generatePlan is reachable with no token
//  (auth-optional, mirrors POST /v1/calculate).
//

import XCTest
@testable import Incomatic

final class BudgetServiceTests: XCTestCase {

    private var service: BudgetService!

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        service = BudgetService()
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubURLProtocol.stub = nil
        service = nil
        super.tearDown()
    }

    func test_getBudget_noToken_throwsNotAuthenticatedWithoutHittingNetwork() async {
        service.sessionTokenProvider = { nil }

        do {
            _ = try await service.getBudget()
            XCTFail("expected notAuthenticated")
        } catch BudgetService.BudgetServiceError.notAuthenticated {
            // expected
        } catch {
            XCTFail("expected BudgetServiceError.notAuthenticated, got \(error)")
        }
    }

    func test_getBudget_404_throwsNotFound() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 404, body: nil)

        do {
            _ = try await service.getBudget()
            XCTFail("expected notFound")
        } catch BudgetService.BudgetServiceError.notFound {
            // expected
        } catch {
            XCTFail("expected BudgetServiceError.notFound, got \(error)")
        }
    }

    func test_getBudget_malformedJSON_throwsDecodingError() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 200, body: "not json".data(using: .utf8))

        do {
            _ = try await service.getBudget()
            XCTFail("expected decoding error")
        } catch BudgetService.BudgetServiceError.decoding {
            // expected
        } catch {
            XCTFail("expected BudgetServiceError.decoding, got \(error)")
        }
    }

    func test_saveBudget_401_throwsNotAuthenticated() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 401, body: "unauthorized".data(using: .utf8))

        do {
            _ = try await service.saveBudget(Budget())
            XCTFail("expected notAuthenticated")
        } catch BudgetService.BudgetServiceError.notAuthenticated {
            // expected
        } catch {
            XCTFail("expected BudgetServiceError.notAuthenticated, got \(error)")
        }
    }

    func test_generatePlan_withNoToken_stillReachesNetwork_authOptional() async {
        service.sessionTokenProvider = { nil }
        StubURLProtocol.stub = .init(statusCode: 503, body: nil)
        let request = BudgetPlanRequest(budget: Budget(), payFrequency: "BIWEEKLY", netIncomePerPeriod: 2_000)

        do {
            _ = try await service.generatePlan(request)
            XCTFail("expected planUnavailable")
        } catch BudgetService.BudgetServiceError.planUnavailable {
            // 503 was reached at all (rather than a pre-flight notAuthenticated) —
            // confirms generatePlan doesn't require a session token.
        } catch {
            XCTFail("expected BudgetServiceError.planUnavailable, got \(error)")
        }
    }

    func test_getBudget_429_throwsRateLimited() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(
            statusCode: 429,
            body: "{\"error\":\"Too many requests. Retry in a minute.\"}".data(using: .utf8)
        )

        do {
            _ = try await service.getBudget()
            XCTFail("expected rateLimited")
        } catch BudgetService.BudgetServiceError.rateLimited {
            // The raw JSON body must not reach the user as an error string.
        } catch {
            XCTFail("expected BudgetServiceError.rateLimited, got \(error)")
        }
    }

    func test_deleteBudget_transportFailure_throwsNetworkError() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 0, transportError: URLError(.networkConnectionLost))

        do {
            try await service.deleteBudget()
            XCTFail("expected network error")
        } catch BudgetService.BudgetServiceError.network {
            // expected
        } catch {
            XCTFail("expected BudgetServiceError.network, got \(error)")
        }
    }
}
