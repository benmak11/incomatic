//
//
//  CalculationRequestBuilder.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Pure function that maps CalculatorState to the POST /v1/calculate request body
//  plus the bookkeeping values (baseAnnual, bonusAnnual, BenefitsInput) the
//  result screen needs for display fallbacks.

import Foundation

struct BuiltCalculationRequest {
    let request: SalaryCalculationRequest
    let baseAnnual: Double
    let bonusAnnual: Double
    let benefits: BenefitsInput
}

func buildCalculationRequest(state: CalculatorState) -> BuiltCalculationRequest {
    let periods = state.payFrequency.periodsPerYear

    let salaryAmt = Double(state.salaryAmount) ?? 0
    let salaryRow: SalaryRow? = (state.incomeType == .salary && salaryAmt > 0)
        ? SalaryRow(amount: salaryAmt, basis: state.salaryBasis.apiValue)
        : nil

    let rate = Double(state.hourlyRate) ?? 0
    let hourlyRow: HourlyRow? = (state.incomeType == .hourly && rate > 0)
        ? HourlyRow(
            rate: rate,
            regularHours: Double(state.regularHoursPerPeriod),
            overtimeHours: Double(state.overtimeHoursPerPeriod),
            overtimeMultiplier: nil,
            doubleTimeHours: nil,
            doubleTimeMultiplier: nil
          )
        : nil

    let bonus = Double(state.bonusAmount) ?? 0
    let commission = Double(state.commissionAmount) ?? 0

    let earnings: Earnings? = (salaryRow != nil || hourlyRow != nil || bonus > 0 || commission > 0)
        ? Earnings(
            salary: salaryRow,
            hourly: hourlyRow,
            bonus: bonus > 0 ? bonus : nil,
            commission: commission > 0 ? commission : nil
          )
        : nil

    func annual(_ s: String) -> Double? {
        guard let v = Double(s), v > 0 else { return nil }
        return v * periods
    }
    let medAnnual  = annual(state.medicalPerPeriod)
    let dentAnnual = annual(state.dentalPerPeriod)
    let visAnnual  = annual(state.visionPerPeriod)
    let fsaAnnual  = annual(state.healthcareFsaPerPeriod)
    let dcaAnnual  = annual(state.dependentCareFsaPerPeriod)
    let hsaAnnual  = annual(state.hsaPerPeriod)

    let namedCustomDeductions: [NamedDeduction] = state.customDeductions
        .enumerated()
        .compactMap { idx, deduction in
            guard let amt = Double(deduction.amount), amt > 0 else { return nil }
            let trimmed = deduction.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = trimmed.isEmpty ? "Custom Deduction \(idx + 1)" : trimmed
            return NamedDeduction(name: label, amount: amt)
        }

    let pretax = PreTaxDeductions(
        pensionPercent: state.traditional401kPercent > 0 ? state.traditional401kPercent / 100.0 : nil,
        fixed: nil,
        hsa: hsaAnnual,
        medical: medAnnual,
        dental: dentAnnual,
        vision: visAnnual,
        healthcareFsa: fsaAnnual,
        dependentCareFsa: dcaAnnual,
        customDeductions: namedCustomDeductions.isEmpty ? nil : namedCustomDeductions
    )

    let posttax = PostTaxDeductions(
        fixed: nil,
        roth401kPercent: state.roth401kPercent > 0 ? state.roth401kPercent / 100.0 : nil,
        studentLoanPlan: nil
    )

    let allowancesCount = max(0, Int(state.allowances) ?? 0)

    let w4HasData = (Double(state.dependentsAmount) ?? 0) > 0
        || (Double(state.otherIncome) ?? 0) > 0
        || (Double(state.itemizedDeductions) ?? 0) > 0
        || (Double(state.additionalWithholding) ?? 0) > 0
        || state.exemptFederal || state.exemptSocialSecurity || state.exemptMedicare
        || state.useOldW4 || state.nonresidentAlien
    // On the pre-2020 W-4 the modern step-3/4 fields don't exist — send nil so they
    // can't skew the legacy allowance-based calc.
    let w4: W4? = w4HasData ? W4(
        useOldW4: state.useOldW4 ? true : nil,
        nonresidentAlien: state.nonresidentAlien ? true : nil,
        dependentsAmount: state.useOldW4 ? nil : Double(state.dependentsAmount),
        otherIncome: state.useOldW4 ? nil : Double(state.otherIncome),
        itemizedDeductions: state.useOldW4 ? nil : Double(state.itemizedDeductions),
        additionalWithholding: Double(state.additionalWithholding),
        exemptFederal: state.exemptFederal ? true : nil,
        exemptSocialSecurity: state.exemptSocialSecurity ? true : nil,
        exemptMedicare: state.exemptMedicare ? true : nil
    ) : nil

    let payDateString: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: state.payDate)
    }()

    let request = SalaryCalculationRequest(
        country: "US",
        taxYear: 2025,
        annualSalary: nil,
        bonus: nil,
        earnings: earnings,
        payDate: payDateString,
        cadence: state.payFrequency.apiValue,
        pretax: pretax,
        posttax: posttax,
        countryOptions: CountryOptions(
            US: USOptions(
                state: state.selectedStateCode,
                filingStatus: state.filingStatus.apiValue,
                allowances: state.useOldW4 ? allowancesCount : nil,
                w4: w4
            ),
            UK: nil
        )
    )

    let baseAnnual: Double = {
        if let s = salaryRow {
            return s.basis == "PER_YEAR" ? s.amount : s.amount * periods
        }
        if let h = hourlyRow {
            let rh = (h.regularHours ?? 0) * h.rate * periods
            let oh = (h.overtimeHours ?? 0) * h.rate * (h.overtimeMultiplier ?? 1.5) * periods
            return rh + oh
        }
        return 0
    }()

    return BuiltCalculationRequest(
        request: request,
        baseAnnual: baseAnnual,
        bonusAnnual: bonus + commission,
        benefits: BenefitsInput(
            medicalPremium: medAnnual ?? 0,
            dentalPremium: dentAnnual ?? 0,
            lifeInsurancePremium: 0
        )
    )
}
