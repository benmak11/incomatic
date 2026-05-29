//
//  
//  LivePreviewEstimator.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Quick client-side approximation so the sticky CTA can show "projected take-home
//  per period" as the user types. The server's /v1/calculate result is always
//  authoritative on Calculate; this is just keystroke-responsive guidance.
//

import Foundation

struct LivePreview {
    let perPeriod: Double?
    let pctOfGross: Double?
}

func livePreview(state: CalculatorState) -> LivePreview {
    let salary = Double(state.salaryAmount) ?? 0
    let hourly = (Double(state.hourlyRate) ?? 0) *
        ((Double(state.regularHoursPerPeriod) ?? 0) +
         (Double(state.overtimeHoursPerPeriod) ?? 0) * 1.5) *
        state.payFrequency.periodsPerYear
    let bonus = Double(state.bonusAmount) ?? 0
    let comm  = Double(state.commissionAmount) ?? 0
    let annualGross = (state.incomeType == .salary
        ? (state.salaryBasis == .perYear ? salary : salary * state.payFrequency.periodsPerYear)
        : hourly) + bonus + comm
    guard annualGross > 0 else { return LivePreview(perPeriod: nil, pctOfGross: nil) }

    let periods = state.payFrequency.periodsPerYear
    func ann(_ s: String) -> Double { (Double(s) ?? 0) * periods }
    let pretaxBenefits = ann(state.medicalPerPeriod) + ann(state.dentalPerPeriod) +
        ann(state.visionPerPeriod) + ann(state.healthcareFsaPerPeriod) +
        ann(state.dependentCareFsaPerPeriod) + ann(state.hsaPerPeriod) +
        (annualGross * (state.traditional401kPercent / 100.0))

    // 2025 standard deduction (single)
    let taxable = max(0, annualGross - pretaxBenefits - 14_600)

    // Progressive federal (2025 single, rough)
    let brackets: [(cap: Double, rate: Double)] = [
        (11_600, 0.10), (47_150, 0.12), (100_525, 0.22),
        (191_950, 0.24), (243_725, 0.32), (609_350, 0.35),
        (.infinity, 0.37),
    ]
    var fed = 0.0, prev = 0.0, rem = taxable
    for b in brackets {
        let slice = min(rem, b.cap - prev)
        if slice <= 0 { break }
        fed += slice * b.rate
        rem -= slice
        prev = b.cap
        if rem <= 0 { break }
    }

    let stateRates: [String: Double] = [
        "CA": 0.06, "NY": 0.055, "TX": 0, "FL": 0, "MD": 0.0475,
        "WA": 0, "IL": 0.0495, "MA": 0.05,
    ]
    let stateTax = taxable * (stateRates[state.selectedStateCode] ?? 0.04)
    let ss = min(annualGross, 168_600) * 0.062
    let medicare = annualGross * 0.0145
    let rothAmt = annualGross * (state.roth401kPercent / 100.0)
    let net = annualGross - fed - stateTax - ss - medicare - pretaxBenefits - rothAmt
    let perPeriod = net / periods

    // Pct of gross uses the same definition the old code did (salary + bonus + commission, no hourly)
    let annualForPct = (state.salaryBasis == .perYear ? salary : salary * periods) + bonus + comm
    let grossPerPeriod = annualForPct > 0 ? annualForPct / periods : 0
    let pct: Double? = grossPerPeriod > 0 ? (perPeriod / grossPerPeriod) * 100 : nil

    return LivePreview(perPeriod: perPeriod, pctOfGross: pct)
}
