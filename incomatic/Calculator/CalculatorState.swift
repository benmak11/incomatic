//
//  
//  CalculatorState.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Single source of truth for the four Calculator sections.
//  Replaces the 22 @State vars that previously lived on CalculatorTab.
//

import Foundation
import Observation

@Observable
final class CalculatorState {
    var activeSection: CalculatorSection = .earnings

    // Earnings
    var payFrequency: PayFrequency = .biweekly
    var incomeType: IncomeType = .salary
    var salaryAmount: String = ""
    var salaryBasis: SalaryBasis = .perYear
    var hourlyRate: String = ""
    var regularHoursPerPeriod: String = "80"
    var overtimeHoursPerPeriod: String = ""
    var bonusAmount: String = ""        // lump sum
    /// Bonus payout date. Nil = "This year" (assumed current tax year).
    var bonusDate: Date? = nil
    /// ON = same amount recurs every year from the payout-date year onward.
    var bonusRecurring: Bool = false
    var commissionAmount: String = ""   // annual
    /// Manual annual RSU value vesting this year (signed-out entry / explicit override).
    var rsuVestingAmount: String = ""
    /// RSU value vesting this tax year derived from saved grants (EquityStore).
    var grantDerivedRsuAnnual: Double = 0
    /// Set when grants or the bonus's year-inclusion change after a result exists,
    /// so the UI can nudge "Recalculate". Cleared on the next calculation.
    var needsRecalculation: Bool = false
    var payDate: Date = Date()

    // Federal
    var filingStatus: FilingStatus = .single
    var useOldW4: Bool = false
    var nonresidentAlien: Bool = false
    var multipleJobs: Bool = false
    var allowances: String = "0"          // pre-2020 W-4 only
    var dependentsAmount: String = ""
    var otherIncome: String = ""
    var itemizedDeductions: String = ""
    var additionalWithholding: String = ""   // per period
    var exemptFederal: Bool = false
    var exemptSocialSecurity: Bool = false
    var exemptMedicare: Bool = false

    // State / territory
    var statesList: [SalaryCalculatorService.StateEntry] = []
    var selectedStateCode: String = "CA"
    var livesInDifferentState: Bool = false
    var resideStateCode: String = ""
    var nonResidencyCertificate: Bool = false
    var mdCounty: String = "Anne Arundel"

    // Benefits
    var medicalPerPeriod: String = ""
    var dentalPerPeriod: String = ""
    var visionPerPeriod: String = ""
    var healthcareFsaPerPeriod: String = ""
    var dependentCareFsaPerPeriod: String = ""
    var hsaPerPeriod: String = ""
    var traditional401kPercent: Double = 6.0
    var roth401kPercent: Double = 0.0
    var customDeductions: [CustomDeduction] = []

    // ─ Derived earnings helpers ──────────────────────────────

    /// Effective annual RSU value: an explicit manual override wins over the
    /// grant-derived total (design §A — override is explicit, never silent).
    var effectiveRsuAnnual: Double {
        let manual = Double(rsuVestingAmount) ?? 0
        return manual > 0 ? manual : grantDerivedRsuAnnual
    }

    var bonusStartYear: Int? {
        bonusDate.map { Calendar.current.component(.year, from: $0) }
    }

    /// Mirrors the server's inclusion rule: recurring counts from its start year
    /// onward; one-time only in its payout year. Nil date = current tax year.
    var bonusIncludedThisYear: Bool {
        guard (Double(bonusAmount) ?? 0) > 0 else { return false }
        guard let year = bonusStartYear else { return true }
        return bonusRecurring ? year <= AppConfig.taxYear : year == AppConfig.taxYear
    }

    var canCalculate: Bool {
        let hasSalary = (Double(salaryAmount) ?? 0) > 0
        let hasHourly = (Double(hourlyRate) ?? 0) > 0
        let hasBonus  = (Double(bonusAmount) ?? 0) > 0
        let hasComm   = (Double(commissionAmount) ?? 0) > 0
        let hasRsu    = effectiveRsuAnnual > 0
        return (hasSalary || hasHourly || hasBonus || hasComm || hasRsu) && !selectedStateCode.isEmpty
    }

    func stateName(for code: String) -> String? {
        statesList.first(where: { $0.code == code })?.name
    }
}
