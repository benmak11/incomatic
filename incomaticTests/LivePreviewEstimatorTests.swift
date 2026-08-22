//
//  LivePreviewEstimatorTests.swift
//  incomaticTests
//
//  The estimator duplicates federal constants that live in the backend's rule
//  pack, because it runs on every keystroke and cannot call the server. That
//  makes it the one part of the app which silently goes stale each January,
//  and it had drifted two full years before anyone noticed: the comment said
//  2025 while the numbers were 2024's.
//
//  Android has carried an equivalent test since it was written, and that test
//  is what failed loudly when the constants were corrected. iOS had none, which
//  is precisely why the same drift went unremarked here. These pin the figures
//  so the next drift is a red test rather than a quietly wrong ribbon.
//

import XCTest
@testable import Incomatic

@MainActor
final class LivePreviewEstimatorTests: XCTestCase {

    private func state(salary: String, stateCode: String = "CA") -> CalculatorState {
        let s = CalculatorState()
        s.salaryAmount = salary
        s.salaryBasis = .perYear
        s.selectedStateCode = stateCode
        s.payFrequency = .biweekly
        return s
    }

    func test_noIncomeProducesNoPreview() {
        let preview = livePreview(state: state(salary: ""))
        XCTAssertNil(preview.perPeriod)
        XCTAssertNil(preview.pctOfGross)
    }

    /// taxable = 100000 - 16100 standard deduction = 83900.
    /// fed = 12400*.10 + 38000*.12 + 33500*.22 = 1240 + 4560 + 7370 = 13170
    /// CA = 83900*.06 = 5034; ss = 100000*.062 = 6200; medicare = 100000*.0145 = 1450
    /// net = 100000 - (13170+5034+6200+1450) = 74146, over 26 biweekly periods.
    ///
    /// 13170 is the same federal figure the deployed engine returns for 2026
    /// single on 100k, so this is anchored to the backend rather than being a
    /// snapshot of whatever the estimator happens to compute.
    func test_appliesMarginalFederalBracketsAndTheKnownCARate() {
        let preview = livePreview(state: state(salary: "100000"))
        XCTAssertEqual(preview.perPeriod ?? 0, 74_146.0 / 26, accuracy: 0.01)
        XCTAssertEqual(preview.pctOfGross ?? 0, 74.146, accuracy: 0.01)
    }

    /// The default rate (.04) is lower than CA's (.06), so an unknown code nets
    /// more: 83900*.04 = 3356, net = 100000 - (13170+3356+6200+1450) = 75824.
    func test_fallsBackToTheDefaultStateRateForAnUnrecognizedCode() {
        let known = livePreview(state: state(salary: "100000", stateCode: "CA"))
        let unknown = livePreview(state: state(salary: "100000", stateCode: "ZZ"))
        XCTAssertGreaterThan(unknown.perPeriod ?? 0, known.perPeriod ?? 0)
        XCTAssertEqual(unknown.perPeriod ?? 0, 75_824.0 / 26, accuracy: 0.01)
    }

    /// A state with no income tax should net exactly the state portion more.
    func test_aNoTaxStateNetsTheStatePortionMore() {
        let ca = livePreview(state: state(salary: "100000", stateCode: "CA"))
        let tx = livePreview(state: state(salary: "100000", stateCode: "TX"))
        XCTAssertEqual((tx.perPeriod ?? 0) - (ca.perPeriod ?? 0), 5_034.0 / 26, accuracy: 0.01)
    }
}
