//
//  HistoryDetailMapper.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Bridges a server-side SavedCalculationDetail (the original request + response)
//  into the local ViewFriendlyResponse shape so EarningsBreakdownView can render
//  it without code changes. Mirrors SalaryCalculatorService.transformToViewFriendly.
//

import Foundation

enum HistoryDetailMapper {

    static func viewFriendly(from detail: SavedCalculationDetail) -> ViewFriendlyResponse {
        let request = detail.request
        let response = detail.response
        let cadence = request.cadence ?? "ANNUAL"

        let periodsPerYear: Double
        let displayCadence: String
        switch cadence {
        case "DAILY":       periodsPerYear = 260; displayCadence = "daily"
        case "WEEKLY":      periodsPerYear = 52;  displayCadence = "weekly"
        case "BIWEEKLY":    periodsPerYear = 26;  displayCadence = "biweekly"
        case "SEMIMONTHLY": periodsPerYear = 24;  displayCadence = "semi-monthly"
        case "MONTHLY":     periodsPerYear = 12;  displayCadence = "monthly"
        case "QUARTERLY":   periodsPerYear = 4;   displayCadence = "quarterly"
        case "SEMIANNUAL":  periodsPerYear = 2;   displayCadence = "semi-annual"
        default:            periodsPerYear = 1;   displayCadence = "annual"
        }

        let annualGross = periodsPerYear == 1
            ? response.grossPerCadence
            : response.grossPerCadence * periodsPerYear
        let annualNet = periodsPerYear == 1
            ? response.netPerCadence
            : response.netPerCadence * periodsPerYear

        var federalTax: TaxBreakdown?
        var stateTax: TaxBreakdown?
        var socialSecurity: TaxBreakdown?
        var medicare: TaxBreakdown?
        var pension401k: Double = 0
        var totalTaxes: Double = 0

        for item in response.lineItems {
            let name = item.name
            if name.contains("Federal Income Tax") {
                federalTax = TaxBreakdown(amount: item.amount, rate: nil, description: name)
                totalTaxes += item.amount
            } else if name.contains("State Income Tax") {
                stateTax = TaxBreakdown(amount: item.amount, rate: nil, description: name)
                totalTaxes += item.amount
            } else if name.contains("Social Security") {
                socialSecurity = TaxBreakdown(amount: item.amount, rate: 6.2, description: "Social Security")
                totalTaxes += item.amount
            } else if name.contains("Medicare") {
                medicare = TaxBreakdown(amount: item.amount, rate: 1.45, description: "Medicare")
                totalTaxes += item.amount
            } else if name.contains("Employee Pension") || name.contains("401") {
                pension401k = item.amount
            }
        }

        let ficaCombined = (socialSecurity?.amount ?? 0) + (medicare?.amount ?? 0)
        let effectiveTaxRate = annualGross > 0
            ? (totalTaxes * periodsPerYear / annualGross) * 100
            : 0

        // Pretax medical/dental are stored as annual amounts on the request.
        let medicalAnnual = request.pretax?.medical ?? 0
        let dentalAnnual = request.pretax?.dental ?? 0

        let baseAnnual = (request.earnings?.salary?.amount).map { amount -> Double in
            if request.earnings?.salary?.basis == "PER_PERIOD" {
                return amount * periodsPerYear
            }
            return amount
        } ?? (request.annualSalary ?? 0)
        let bonusAnnual = request.earnings?.bonus ?? request.bonus ?? 0

        return ViewFriendlyResponse(
            grossPay: GrossPayDetails(
                baseSalaryPerPeriod: response.baseSalaryPerCadence ?? (baseAnnual / periodsPerYear),
                bonusPerPeriod: response.bonusPerCadence ?? (bonusAnnual / periodsPerYear),
                totalPerPeriod: response.grossPerCadence,
                annualTotal: annualGross,
                annualBonus: bonusAnnual,
                payFrequency: displayCadence
            ),
            taxes: Taxes(
                federal: federalTax,
                stateTax: stateTax,
                ficaCombined: ficaCombined,
                socialSecurity: socialSecurity,
                medicare: medicare,
                totalTaxes: totalTaxes,
                effectiveTaxRate: effectiveTaxRate
            ),
            benefits: BenefitsBreakdown(
                medical: medicalAnnual / periodsPerYear,
                dental: dentalAnnual / periodsPerYear,
                retirement401k: pension401k,
                lifeInsurance: 0
            ),
            netPay: NetPay(
                perPayPeriod: response.netPerCadence,
                annual: annualNet,
                takeHomePercentage: annualGross > 0 ? (annualNet / annualGross) * 100 : 0
            ),
            currency: response.currency,
            calculationId: response.calculationId,
            rulePackVersion: response.rulePackVersion,
            lineItems: response.lineItems
        )
    }
}
