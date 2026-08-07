//
//  CalculatorStatePersistence.swift
//  incomatic
//
//  Created by Ben Makusha on 08/06/2026
//
//  CalculatorState lived only in memory, so every cold launch threw away
//  everything the user had entered. That is the retention leak: a returning
//  user faced an empty form and re-typed their salary, or left.
//

import Foundation

/// The user's inputs, and only those.
///
/// A snapshot rather than making `CalculatorState` itself `Codable`, because
/// three of its properties must **not** survive a launch and an opt-out list is
/// too easy to forget to update:
///
/// - `statesList` is fetched from the backend; a stale copy would go on being
///   served after the server's list changed.
/// - `grantDerivedRsuAnnual` is derived from `EquityStore` and is recomputed on
///   load; persisting it would let a deleted grant keep inflating the estimate.
/// - `needsRecalculation` and `activeSection` are transient UI state.
///
/// Every field is optional-tolerant on decode: a build that adds a field must
/// still be able to read a file written by the build before it, or the upgrade
/// silently wipes the very data this exists to keep.
struct CalculatorStateSnapshot: Codable, Equatable {
    // Earnings
    var payFrequency: PayFrequency = .biweekly
    var incomeType: IncomeType = .salary
    var salaryAmount: String = ""
    var salaryBasis: SalaryBasis = .perYear
    var hourlyRate: String = ""
    var regularHoursPerPeriod: String = "80"
    var overtimeHoursPerPeriod: String = ""
    var bonusAmount: String = ""
    var bonusDate: Date?
    var bonusRecurring: Bool = false
    var commissionAmount: String = ""
    var rsuVestingAmount: String = ""
    var payDate: Date = Date()

    // Federal
    var filingStatus: FilingStatus = .single
    var useOldW4: Bool = false
    var allowances: String = "0"
    var dependentsAmount: String = ""
    var otherIncome: String = ""
    var itemizedDeductions: String = ""
    var additionalWithholding: String = ""
    var exemptFederal: Bool = false
    var exemptSocialSecurity: Bool = false
    var exemptMedicare: Bool = false

    // State
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
    var traditional401kPercent: Double = 0
    var roth401kPercent: Double = 0
    var customDeductions: [CustomDeduction] = []

    init() {}

    /// Hand-written so a **missing key falls back to its default instead of
    /// throwing**. Swift's synthesized `Decodable` raises `keyNotFound`, which
    /// would make a file written by an older build undecodable the moment a
    /// field is added — silently wiping the inputs this type exists to keep.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = CalculatorStateSnapshot()
        payFrequency = try c.decodeIfPresent(PayFrequency.self, forKey: .payFrequency) ?? fallback.payFrequency
        incomeType = try c.decodeIfPresent(IncomeType.self, forKey: .incomeType) ?? fallback.incomeType
        salaryAmount = try c.decodeIfPresent(String.self, forKey: .salaryAmount) ?? fallback.salaryAmount
        salaryBasis = try c.decodeIfPresent(SalaryBasis.self, forKey: .salaryBasis) ?? fallback.salaryBasis
        hourlyRate = try c.decodeIfPresent(String.self, forKey: .hourlyRate) ?? fallback.hourlyRate
        regularHoursPerPeriod = try c.decodeIfPresent(String.self, forKey: .regularHoursPerPeriod) ?? fallback.regularHoursPerPeriod
        overtimeHoursPerPeriod = try c.decodeIfPresent(String.self, forKey: .overtimeHoursPerPeriod) ?? fallback.overtimeHoursPerPeriod
        bonusAmount = try c.decodeIfPresent(String.self, forKey: .bonusAmount) ?? fallback.bonusAmount
        bonusRecurring = try c.decodeIfPresent(Bool.self, forKey: .bonusRecurring) ?? fallback.bonusRecurring
        commissionAmount = try c.decodeIfPresent(String.self, forKey: .commissionAmount) ?? fallback.commissionAmount
        rsuVestingAmount = try c.decodeIfPresent(String.self, forKey: .rsuVestingAmount) ?? fallback.rsuVestingAmount
        payDate = try c.decodeIfPresent(Date.self, forKey: .payDate) ?? fallback.payDate
        filingStatus = try c.decodeIfPresent(FilingStatus.self, forKey: .filingStatus) ?? fallback.filingStatus
        useOldW4 = try c.decodeIfPresent(Bool.self, forKey: .useOldW4) ?? fallback.useOldW4
        allowances = try c.decodeIfPresent(String.self, forKey: .allowances) ?? fallback.allowances
        dependentsAmount = try c.decodeIfPresent(String.self, forKey: .dependentsAmount) ?? fallback.dependentsAmount
        otherIncome = try c.decodeIfPresent(String.self, forKey: .otherIncome) ?? fallback.otherIncome
        itemizedDeductions = try c.decodeIfPresent(String.self, forKey: .itemizedDeductions) ?? fallback.itemizedDeductions
        additionalWithholding = try c.decodeIfPresent(String.self, forKey: .additionalWithholding) ?? fallback.additionalWithholding
        exemptFederal = try c.decodeIfPresent(Bool.self, forKey: .exemptFederal) ?? fallback.exemptFederal
        exemptSocialSecurity = try c.decodeIfPresent(Bool.self, forKey: .exemptSocialSecurity) ?? fallback.exemptSocialSecurity
        exemptMedicare = try c.decodeIfPresent(Bool.self, forKey: .exemptMedicare) ?? fallback.exemptMedicare
        selectedStateCode = try c.decodeIfPresent(String.self, forKey: .selectedStateCode) ?? fallback.selectedStateCode
        livesInDifferentState = try c.decodeIfPresent(Bool.self, forKey: .livesInDifferentState) ?? fallback.livesInDifferentState
        resideStateCode = try c.decodeIfPresent(String.self, forKey: .resideStateCode) ?? fallback.resideStateCode
        nonResidencyCertificate = try c.decodeIfPresent(Bool.self, forKey: .nonResidencyCertificate) ?? fallback.nonResidencyCertificate
        mdCounty = try c.decodeIfPresent(String.self, forKey: .mdCounty) ?? fallback.mdCounty
        medicalPerPeriod = try c.decodeIfPresent(String.self, forKey: .medicalPerPeriod) ?? fallback.medicalPerPeriod
        dentalPerPeriod = try c.decodeIfPresent(String.self, forKey: .dentalPerPeriod) ?? fallback.dentalPerPeriod
        visionPerPeriod = try c.decodeIfPresent(String.self, forKey: .visionPerPeriod) ?? fallback.visionPerPeriod
        healthcareFsaPerPeriod = try c.decodeIfPresent(String.self, forKey: .healthcareFsaPerPeriod) ?? fallback.healthcareFsaPerPeriod
        dependentCareFsaPerPeriod = try c.decodeIfPresent(String.self, forKey: .dependentCareFsaPerPeriod) ?? fallback.dependentCareFsaPerPeriod
        hsaPerPeriod = try c.decodeIfPresent(String.self, forKey: .hsaPerPeriod) ?? fallback.hsaPerPeriod
        traditional401kPercent = try c.decodeIfPresent(Double.self, forKey: .traditional401kPercent) ?? fallback.traditional401kPercent
        roth401kPercent = try c.decodeIfPresent(Double.self, forKey: .roth401kPercent) ?? fallback.roth401kPercent
        customDeductions = try c.decodeIfPresent([CustomDeduction].self, forKey: .customDeductions) ?? fallback.customDeductions
        bonusDate = try c.decodeIfPresent(Date.self, forKey: .bonusDate)
    }

    init(from state: CalculatorState) {
        payFrequency = state.payFrequency
        incomeType = state.incomeType
        salaryAmount = state.salaryAmount
        salaryBasis = state.salaryBasis
        hourlyRate = state.hourlyRate
        regularHoursPerPeriod = state.regularHoursPerPeriod
        overtimeHoursPerPeriod = state.overtimeHoursPerPeriod
        bonusAmount = state.bonusAmount
        bonusDate = state.bonusDate
        bonusRecurring = state.bonusRecurring
        commissionAmount = state.commissionAmount
        rsuVestingAmount = state.rsuVestingAmount
        payDate = state.payDate

        filingStatus = state.filingStatus
        useOldW4 = state.useOldW4
        allowances = state.allowances
        dependentsAmount = state.dependentsAmount
        otherIncome = state.otherIncome
        itemizedDeductions = state.itemizedDeductions
        additionalWithholding = state.additionalWithholding
        exemptFederal = state.exemptFederal
        exemptSocialSecurity = state.exemptSocialSecurity
        exemptMedicare = state.exemptMedicare

        selectedStateCode = state.selectedStateCode
        livesInDifferentState = state.livesInDifferentState
        resideStateCode = state.resideStateCode
        nonResidencyCertificate = state.nonResidencyCertificate
        mdCounty = state.mdCounty

        medicalPerPeriod = state.medicalPerPeriod
        dentalPerPeriod = state.dentalPerPeriod
        visionPerPeriod = state.visionPerPeriod
        healthcareFsaPerPeriod = state.healthcareFsaPerPeriod
        dependentCareFsaPerPeriod = state.dependentCareFsaPerPeriod
        hsaPerPeriod = state.hsaPerPeriod
        traditional401kPercent = state.traditional401kPercent
        roth401kPercent = state.roth401kPercent
        customDeductions = state.customDeductions
    }

    func apply(to state: CalculatorState) {
        state.payFrequency = payFrequency
        state.incomeType = incomeType
        state.salaryAmount = salaryAmount
        state.salaryBasis = salaryBasis
        state.hourlyRate = hourlyRate
        state.regularHoursPerPeriod = regularHoursPerPeriod
        state.overtimeHoursPerPeriod = overtimeHoursPerPeriod
        state.bonusAmount = bonusAmount
        state.bonusDate = bonusDate
        state.bonusRecurring = bonusRecurring
        state.commissionAmount = commissionAmount
        state.rsuVestingAmount = rsuVestingAmount
        state.payDate = payDate

        state.filingStatus = filingStatus
        state.useOldW4 = useOldW4
        state.allowances = allowances
        state.dependentsAmount = dependentsAmount
        state.otherIncome = otherIncome
        state.itemizedDeductions = itemizedDeductions
        state.additionalWithholding = additionalWithholding
        state.exemptFederal = exemptFederal
        state.exemptSocialSecurity = exemptSocialSecurity
        state.exemptMedicare = exemptMedicare

        state.selectedStateCode = selectedStateCode
        state.livesInDifferentState = livesInDifferentState
        state.resideStateCode = resideStateCode
        state.nonResidencyCertificate = nonResidencyCertificate
        state.mdCounty = mdCounty

        state.medicalPerPeriod = medicalPerPeriod
        state.dentalPerPeriod = dentalPerPeriod
        state.visionPerPeriod = visionPerPeriod
        state.healthcareFsaPerPeriod = healthcareFsaPerPeriod
        state.dependentCareFsaPerPeriod = dependentCareFsaPerPeriod
        state.hsaPerPeriod = hsaPerPeriod
        state.traditional401kPercent = traditional401kPercent
        state.roth401kPercent = roth401kPercent
        state.customDeductions = customDeductions
    }
}

/// Where the snapshot lives between launches.
protocol CalculatorStateStorage {
    func load() -> CalculatorStateSnapshot?
    func save(_ snapshot: CalculatorStateSnapshot)
    func clear()
}

struct FileCalculatorStateStorage: CalculatorStateStorage {
    private var fileURL: URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base else { return nil }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("calculator-state.json")
    }

    func load() -> CalculatorStateSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(CalculatorStateSnapshot.self, from: data)
    }

    func save(_ snapshot: CalculatorStateSnapshot) {
        guard let fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}

/// Restores on launch and writes back at the points worth preserving.
///
/// Deliberately not "save on every keystroke": the figures only matter once the
/// user stops typing, and writing the whole snapshot per character would be
/// churn for no gain.
enum CalculatorStatePersistence {
    static var storage: CalculatorStateStorage = FileCalculatorStateStorage()

    static func restore(into state: CalculatorState) {
        storage.load()?.apply(to: state)
    }

    static func save(_ state: CalculatorState) {
        storage.save(CalculatorStateSnapshot(from: state))
    }

    /// Called on account deletion: the inputs are the user's financial details
    /// and must not outlive the account they asked to remove.
    static func clear() {
        storage.clear()
    }
}
