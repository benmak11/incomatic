//
//  EquityServiceTests.swift
//  incomaticTests
//
//  EquityService also hard-codes URLSession.shared — same StubURLProtocol
//  seam as SalaryCalculatorServiceTests. Covers the pre-flight no-token path
//  and the documented status-code contracts from the backend CLAUDE.md:
//  401 -> notAuthenticated, 503 -> lookupUnavailable (Finnhub down/unset),
//  and quote()'s 404 -> unknownSymbol scoping.
//

import XCTest
@testable import Incomatic

final class EquityServiceTests: XCTestCase {

    private var service: EquityService!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
        service = EquityService()
    }

    override func tearDown() {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        StubURLProtocol.stub = nil
        service = nil
        super.tearDown()
    }

    func test_noSessionToken_throwsNotAuthenticatedWithoutHittingNetwork() async {
        service.sessionTokenProvider = { nil }
        // Deliberately leave StubURLProtocol.stub nil: if the pre-flight token
        // check were skipped, the request would fail loudly instead of matching.

        do {
            _ = try await service.listGrants()
            XCTFail("expected notAuthenticated")
        } catch EquityService.EquityError.notAuthenticated {
            // expected
        } catch {
            XCTFail("expected EquityError.notAuthenticated, got \(error)")
        }
    }

    func test_listGrants_malformedJSON_throwsDecodingError() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 200, body: "not json".data(using: .utf8))

        do {
            _ = try await service.listGrants()
            XCTFail("expected decoding error")
        } catch EquityService.EquityError.decoding {
            // expected
        } catch {
            XCTFail("expected EquityError.decoding, got \(error)")
        }
    }

    func test_createGrant_401_throwsNotAuthenticated() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 401, body: "unauthorized".data(using: .utf8))
        let grant = RsuGrant(
            id: nil, ticker: "ACME", company: "Acme", manualPrice: false,
            sharesTotal: 100, pricePerShare: 10, grantDate: "2026-01-01",
            schedule: .init(presetId: "annual4", totalMonths: 48, cliffMonths: 0, freqMonths: 12)
        )

        do {
            _ = try await service.createGrant(grant)
            XCTFail("expected notAuthenticated")
        } catch EquityService.EquityError.notAuthenticated {
            // expected
        } catch {
            XCTFail("expected EquityError.notAuthenticated, got \(error)")
        }
    }

    func test_quote_404_isRemappedToUnknownSymbol() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 404, body: "not found".data(using: .utf8))

        do {
            _ = try await service.quote(symbol: "ZZZZ")
            XCTFail("expected unknownSymbol")
        } catch EquityService.EquityError.unknownSymbol {
            // expected
        } catch {
            XCTFail("expected EquityError.unknownSymbol, got \(error)")
        }
    }

    func test_searchStocks_503_throwsLookupUnavailable() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 503, body: nil)

        do {
            _ = try await service.searchStocks(query: "AAPL")
            XCTFail("expected lookupUnavailable")
        } catch EquityService.EquityError.lookupUnavailable {
            // expected
        } catch {
            XCTFail("expected EquityError.lookupUnavailable, got \(error)")
        }
    }

    func test_deleteGrant_transportFailure_throwsNetworkError() async {
        service.sessionTokenProvider = { "token" }
        StubURLProtocol.stub = .init(statusCode: 0, transportError: URLError(.networkConnectionLost))

        do {
            try await service.deleteGrant(id: "g1")
            XCTFail("expected network error")
        } catch EquityService.EquityError.network {
            // expected
        } catch {
            XCTFail("expected EquityError.network, got \(error)")
        }
    }
}
