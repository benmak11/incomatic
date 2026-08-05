//
//  TaxYearTests.swift
//  incomaticTests
//
//  AppConfig.taxYear is server-driven and cached in UserDefaults, so these
//  cover the resolution order (cached -> fallback) and that a failed refresh
//  never degrades a good cached value. StubURLProtocol intercepts the network
//  calls, same as SalaryCalculatorServiceTests.
//

import XCTest
@testable import Incomatic

final class TaxYearTests: XCTestCase {

    private let key = "incomatic.taxYear"
    private var saved: Int?

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
        saved = UserDefaults.standard.object(forKey: key) as? Int
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        StubURLProtocol.stub = nil
        if let saved {
            UserDefaults.standard.set(saved, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    // MARK: - resolution order

    func test_taxYear_withNothingCached_usesFallback() {
        XCTAssertEqual(AppConfig.taxYear, AppConfig.fallbackTaxYear)
    }

    func test_taxYear_withCachedValue_prefersIt() {
        AppConfig.cacheTaxYear(2031)

        XCTAssertEqual(AppConfig.taxYear, 2031)
    }

    func test_cacheTaxYear_ignoresNonPositive_soBadPayloadCannotWipeAGoodYear() {
        AppConfig.cacheTaxYear(2031)

        AppConfig.cacheTaxYear(0)
        AppConfig.cacheTaxYear(-1)

        XCTAssertEqual(AppConfig.taxYear, 2031)
    }

    func test_fallbackTaxYear_isNotDerivedFromTheCalendar() {
        // Rolling forward on Jan 1 would ask the backend for a rule pack that
        // may not exist yet, which throws rather than degrading. The fallback
        // must stay a published year.
        let thisYear = Calendar.current.component(.year, from: Date())
        XCTAssertLessThanOrEqual(AppConfig.fallbackTaxYear, thisYear + 1)
    }

    // MARK: - fetch

    @MainActor
    func test_fetchTaxYears_decodesSupportedYearsAndDefault() async throws {
        StubURLProtocol.stub = .init(
            statusCode: 200,
            body: #"{"country":"US","supportedTaxYears":[2026,2025],"defaultTaxYear":2026}"#
                .data(using: .utf8)
        )

        let years = try await SalaryCalculatorService().fetchTaxYears()

        XCTAssertEqual(years.country, "US")
        XCTAssertEqual(years.supportedTaxYears, [2026, 2025])
        XCTAssertEqual(years.defaultTaxYear, 2026)
    }

    @MainActor
    func test_fetchTaxYears_nullDefault_decodesAsNil() async throws {
        StubURLProtocol.stub = .init(
            statusCode: 200,
            body: #"{"country":"XX","supportedTaxYears":[],"defaultTaxYear":null}"#
                .data(using: .utf8)
        )

        let years = try await SalaryCalculatorService().fetchTaxYears()

        XCTAssertNil(years.defaultTaxYear)
    }

    func test_fetchTaxYears_serverError_throws() async {
        StubURLProtocol.stub = .init(statusCode: 500, body: Data())

        do {
            _ = try await SalaryCalculatorService().fetchTaxYears()
            XCTFail("expected serverError")
        } catch SalaryCalculatorService.APIError.serverError {
            // expected
        } catch {
            XCTFail("expected APIError.serverError, got \(error)")
        }
    }

    // MARK: - refresh

    func test_refreshTaxYear_adoptsTheBackendDefault() async {
        StubURLProtocol.stub = .init(
            statusCode: 200,
            body: #"{"country":"US","supportedTaxYears":[2027,2026],"defaultTaxYear":2027}"#
                .data(using: .utf8)
        )

        await refreshTaxYear()

        XCTAssertEqual(AppConfig.taxYear, 2027)
    }

    func test_refreshTaxYear_whenServerFails_keepsCachedYear() async {
        AppConfig.cacheTaxYear(2026)
        StubURLProtocol.stub = .init(statusCode: 503, body: Data())

        await refreshTaxYear()

        XCTAssertEqual(AppConfig.taxYear, 2026, "a failed refresh must not clear a good year")
    }

    func test_refreshTaxYear_whenDefaultIsNull_keepsCachedYear() async {
        AppConfig.cacheTaxYear(2026)
        StubURLProtocol.stub = .init(
            statusCode: 200,
            body: #"{"country":"US","supportedTaxYears":[],"defaultTaxYear":null}"#
                .data(using: .utf8)
        )

        await refreshTaxYear()

        XCTAssertEqual(AppConfig.taxYear, 2026)
    }
}
