//
//  CalculationRequestBuilderTests.swift
//  incomaticTests
//
//  buildCalculationRequest(state:) is the single translation point from the
//  22-field CalculatorState to the wire request (plus the bookkeeping values
//  the results screen needs). These tests cover the branches most likely to
//  drift silently: salary vs hourly, dated/recurring bonus + RSU override,
//  pretax/posttax percent conversion, and the pre-2020 W-4 allowances path.
//

import XCTest
@testable import Incomatic

@MainActor
final class CalculationRequestBuilderTests: XCTestCase {

    private func makeState() -> CalculatorState {
        let state = CalculatorState()
        state.selectedStateCode = "CA"
        return state
    }

    func test_salaryPerYear_buildsSalaryRowAndBaseAnnual() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "120000"
        state.salaryBasis = .perYear
        state.payFrequency = .biweekly

        let built = buildCalculationRequest(state: state)

        XCTAssertEqual(built.request.earnings?.salary?.amount, 120_000)
        XCTAssertEqual(built.request.earnings?.salary?.basis, "PER_YEAR")
        XCTAssertNil(built.request.earnings?.hourly)
        XCTAssertEqual(built.baseAnnual, 120_000, accuracy: 0.01)
        XCTAssertEqual(built.bonusAnnual, 0)
        XCTAssertEqual(built.request.cadence, "BIWEEKLY")
        XCTAssertEqual(built.request.countryOptions.US?.state, "CA")
        XCTAssertEqual(built.request.countryOptions.US?.filingStatus, "SINGLE")
    }

    func test_salaryPerPeriod_baseAnnualMultipliesByPeriodsPerYear() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "5000"
        state.salaryBasis = .perPeriod
        state.payFrequency = .monthly

        let built = buildCalculationRequest(state: state)

        XCTAssertEqual(built.request.earnings?.salary?.basis, "PER_PERIOD")
        XCTAssertEqual(built.baseAnnual, 60_000, accuracy: 0.01, "5000/mo * 12 periods")
    }

    func test_hourlyWithOvertime_buildsHourlyRowAndBaseAnnual() {
        let state = makeState()
        state.incomeType = .hourly
        state.hourlyRate = "30"
        state.regularHoursPerPeriod = "80"
        state.overtimeHoursPerPeriod = "5"
        state.payFrequency = .biweekly

        let built = buildCalculationRequest(state: state)

        XCTAssertNil(built.request.earnings?.salary)
        XCTAssertEqual(built.request.earnings?.hourly?.rate, 30)
        XCTAssertEqual(built.request.earnings?.hourly?.regularHours, 80)
        XCTAssertEqual(built.request.earnings?.hourly?.overtimeHours, 5)
        // regular: 80h * $30 * 26 periods = $62,400; OT: 5h * $30 * 1.5 (default mult) * 26 = $5,850.
        XCTAssertEqual(built.baseAnnual, 68_250, accuracy: 0.01)
    }

    func test_bonusDatedRecurringPlusCommissionAndManualRsuOverride_populatesEarnings() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        state.bonusAmount = "10000"
        state.bonusDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 15))
        state.bonusRecurring = true
        state.commissionAmount = "2500"
        state.rsuVestingAmount = "8000"
        state.grantDerivedRsuAnnual = 3000 // manual override should win over grant-derived

        let built = buildCalculationRequest(state: state)

        XCTAssertEqual(built.request.earnings?.bonus, 10_000)
        XCTAssertEqual(built.request.earnings?.bonusDate, "2026-03-15")
        XCTAssertEqual(built.request.earnings?.bonusRecurring, true)
        XCTAssertEqual(built.request.earnings?.commission, 2_500)
        XCTAssertEqual(built.request.earnings?.rsuVesting, 8_000, "manual rsuVestingAmount overrides grant-derived")
        XCTAssertEqual(built.bonusAnnual, 12_500, "bonus + commission")
    }

    func test_rsuVesting_fallsBackToGrantDerivedWhenNoManualOverride() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        state.rsuVestingAmount = ""
        state.grantDerivedRsuAnnual = 4_200

        let built = buildCalculationRequest(state: state)

        XCTAssertEqual(built.request.earnings?.rsuVesting, 4_200)
    }

    func test_noBonusDate_omitsBonusDateButKeepsBonusAmount() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        state.bonusAmount = "5000"
        state.bonusDate = nil

        let built = buildCalculationRequest(state: state)

        XCTAssertEqual(built.request.earnings?.bonus, 5_000)
        XCTAssertNil(built.request.earnings?.bonusDate, "nil date = assumed current tax year server-side")
    }

    func test_pretaxAndPosttaxPercentContributions_convertPercentToFraction() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        state.traditional401kPercent = 6
        state.roth401kPercent = 3

        let built = buildCalculationRequest(state: state)

        XCTAssertEqual(built.request.pretax?.pensionPercent ?? 0, 0.06, accuracy: 0.0001)
        XCTAssertEqual(built.request.posttax?.roth401kPercent ?? 0, 0.03, accuracy: 0.0001)
    }

    func test_zero401kPercents_omitFromRequest() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        state.traditional401kPercent = 0
        state.roth401kPercent = 0

        let built = buildCalculationRequest(state: state)

        XCTAssertNil(built.request.pretax?.pensionPercent)
        XCTAssertNil(built.request.posttax?.roth401kPercent)
    }

    func test_perPeriodBenefitDeductions_convertToAnnualUsingCadence() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        state.payFrequency = .biweekly
        state.medicalPerPeriod = "50"
        state.hsaPerPeriod = "20"

        let built = buildCalculationRequest(state: state)

        XCTAssertEqual(built.request.pretax?.medical ?? 0, 1_300, accuracy: 0.01, "50 * 26 periods")
        XCTAssertEqual(built.request.pretax?.hsa ?? 0, 520, accuracy: 0.01, "20 * 26 periods")
        XCTAssertEqual(built.benefits.medicalPremium, 1_300, accuracy: 0.01)
    }

    func test_customDeductions_filtersZeroAndNonPositiveAndLabelsUnnamed() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        state.customDeductions = [
            CustomDeduction(name: "Union Dues", amount: "40"),
            CustomDeduction(name: "", amount: "15"),
            CustomDeduction(name: "Ignored", amount: "0"),
            CustomDeduction(name: "AlsoIgnored", amount: "not-a-number")
        ]

        let built = buildCalculationRequest(state: state)
        let deductions = built.request.pretax?.customDeductions ?? []

        XCTAssertEqual(deductions.count, 2)
        XCTAssertEqual(deductions[0].name, "Union Dues")
        XCTAssertEqual(deductions[0].amount, 40)
        XCTAssertEqual(deductions[1].name, "Custom Deduction 2", "blank name falls back to a positional label")
        XCTAssertEqual(deductions[1].amount, 15)
    }

    func test_oldW4WithAllowances_setsAllowancesAndSuppressesModernFields() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        state.useOldW4 = true
        state.allowances = "3"
        // Modern-only fields the pre-2020 path must not send.
        state.dependentsAmount = "2000"
        state.otherIncome = "500"
        state.itemizedDeductions = "1000"

        let built = buildCalculationRequest(state: state)

        XCTAssertEqual(built.request.countryOptions.US?.allowances, 3)
        XCTAssertEqual(built.request.countryOptions.US?.w4?.useOldW4, true)
        XCTAssertNil(built.request.countryOptions.US?.w4?.dependentsAmount, "step-3/4 fields must not skew the legacy allowance calc")
        XCTAssertNil(built.request.countryOptions.US?.w4?.otherIncome)
        XCTAssertNil(built.request.countryOptions.US?.w4?.itemizedDeductions)
    }

    func test_modernW4_sendsAllowancesNilAndPopulatesStepFields() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        state.useOldW4 = false
        state.allowances = "5" // should be ignored on the modern path
        state.dependentsAmount = "2000"
        state.exemptMedicare = true

        let built = buildCalculationRequest(state: state)

        XCTAssertNil(built.request.countryOptions.US?.allowances, "allowances only sent on the pre-2020 path")
        XCTAssertNil(built.request.countryOptions.US?.w4?.useOldW4)
        XCTAssertEqual(built.request.countryOptions.US?.w4?.dependentsAmount, 2_000)
        XCTAssertEqual(built.request.countryOptions.US?.w4?.exemptMedicare, true)
    }

    func test_noEarningsData_earningsIsNil() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = ""
        state.hourlyRate = ""
        state.bonusAmount = ""
        state.commissionAmount = ""
        state.rsuVestingAmount = ""
        state.grantDerivedRsuAnnual = 0

        let built = buildCalculationRequest(state: state)

        XCTAssertNil(built.request.earnings)
        XCTAssertEqual(built.baseAnnual, 0)
    }

    func test_noW4Data_w4IsNil() {
        let state = makeState()
        state.incomeType = .salary
        state.salaryAmount = "100000"
        // Every W-4-affecting field left at its default.

        let built = buildCalculationRequest(state: state)

        XCTAssertNil(built.request.countryOptions.US?.w4)
    }
}
