//
//  SalaryCalculatorServiceTests.swift
//  incomaticTests
//
//  SalaryCalculatorService hard-codes URLSession.shared with no injected
//  session — StubURLProtocol (globally registered, see StubURLProtocol.swift)
//  intercepts those requests so these error/decode paths can be tested
//  without a live backend or a production refactor.
//

import XCTest
@testable import Incomatic

final class SalaryCalculatorServiceTests: XCTestCase {

    private var service: SalaryCalculatorService!

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        service = SalaryCalculatorService()
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubURLProtocol.stub = nil
        service = nil
        super.tearDown()
    }

    private func minimalRequest() -> SalaryCalculationRequest {
        SalaryCalculationRequest(
            country: "US", taxYear: 2025, annualSalary: nil, bonus: nil, earnings: nil,
            payDate: nil, cadence: nil, pretax: nil, posttax: nil,
            countryOptions: CountryOptions(US: nil, UK: nil)
        )
    }

    func test_calculateSalary_malformedJSON_throwsDecodingError() async {
        StubURLProtocol.stub = .init(statusCode: 200, body: "not json".data(using: .utf8))

        do {
            _ = try await service.calculateSalary(
                request: minimalRequest(), baseSalaryAnnual: 0, bonusAnnual: 0, benefits: BenefitsInput()
            )
            XCTFail("expected decodingError")
        } catch SalaryCalculatorService.APIError.decodingError {
            // expected
        } catch {
            XCTFail("expected APIError.decodingError, got \(error)")
        }
    }

    func test_calculateSalary_429_throwsRateLimited() async {
        StubURLProtocol.stub = .init(
            statusCode: 429,
            body: "{\"error\":\"Too many requests. Retry in a minute.\"}".data(using: .utf8)
        )

        do {
            _ = try await service.calculateSalary(
                request: minimalRequest(), baseSalaryAnnual: 0, bonusAnnual: 0, benefits: BenefitsInput()
            )
            XCTFail("expected rateLimited")
        } catch SalaryCalculatorService.APIError.rateLimited {
            // /v1/calculate is throttled even anonymously, so this is the reachable one.
        } catch {
            XCTFail("expected APIError.rateLimited, got \(error)")
        }
    }

    func test_calculateSalary_serverErrorStatus_throwsServerErrorWithBody() async {
        StubURLProtocol.stub = .init(statusCode: 500, body: "boom".data(using: .utf8))

        do {
            _ = try await service.calculateSalary(
                request: minimalRequest(), baseSalaryAnnual: 0, bonusAnnual: 0, benefits: BenefitsInput()
            )
            XCTFail("expected serverError")
        } catch SalaryCalculatorService.APIError.serverError(let message) {
            XCTAssertEqual(message, "boom")
        } catch {
            XCTFail("expected APIError.serverError, got \(error)")
        }
    }

    func test_calculateSalary_transportFailure_throwsNetworkError() async {
        StubURLProtocol.stub = .init(statusCode: 0, transportError: URLError(.notConnectedToInternet))

        do {
            _ = try await service.calculateSalary(
                request: minimalRequest(), baseSalaryAnnual: 0, bonusAnnual: 0, benefits: BenefitsInput()
            )
            XCTFail("expected networkError")
        } catch SalaryCalculatorService.APIError.networkError {
            // expected
        } catch {
            XCTFail("expected APIError.networkError, got \(error)")
        }
    }

    func test_fetchUSStates_malformedJSON_throwsDecodingError() async {
        StubURLProtocol.stub = .init(statusCode: 200, body: "not json".data(using: .utf8))

        do {
            _ = try await service.fetchUSStates()
            XCTFail("expected decodingError")
        } catch SalaryCalculatorService.APIError.decodingError {
            // expected
        } catch {
            XCTFail("expected APIError.decodingError, got \(error)")
        }
    }

    func test_fetchUSStates_nonSuccessStatus_throwsServerError() async {
        StubURLProtocol.stub = .init(statusCode: 503, body: "down".data(using: .utf8))

        do {
            _ = try await service.fetchUSStates()
            XCTFail("expected serverError")
        } catch SalaryCalculatorService.APIError.serverError(let message) {
            XCTAssertEqual(message, "down")
        } catch {
            XCTFail("expected APIError.serverError, got \(error)")
        }
    }

    func test_fetchUSStates_transportFailure_throwsNetworkError() async {
        StubURLProtocol.stub = .init(statusCode: 0, transportError: URLError(.timedOut))

        do {
            _ = try await service.fetchUSStates()
            XCTFail("expected networkError")
        } catch SalaryCalculatorService.APIError.networkError {
            // expected
        } catch {
            XCTFail("expected APIError.networkError, got \(error)")
        }
    }
}
