//
//  SalaryCalculatorService.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//
//  API service for calculating salary breakdown.
//

import Foundation

// MARK: - API Request Models

nonisolated struct SalaryCalculationRequest: Codable {
    let country: String
    let taxYear: Int
    /// Legacy combined annual amount. When `earnings` is set, prefer that.
    let annualSalary: Double?
    /// Legacy bonus shim. When `earnings.bonus` is set, prefer that.
    let bonus: Double?
    /// Structured earnings (salary OR hourly + bonus + commission). Preferred.
    let earnings: Earnings?
    /// ISO-8601 date string (e.g. "2026-05-28"). Optional, informational.
    let payDate: String?
    let cadence: String?
    let pretax: PreTaxDeductions?
    let posttax: PostTaxDeductions?
    let countryOptions: CountryOptions
}

nonisolated struct Earnings: Codable {
    let salary: SalaryRow?
    let hourly: HourlyRow?
    let bonus: Double?
    let commission: Double?
}

nonisolated struct SalaryRow: Codable {
    let amount: Double
    /// "PER_YEAR" or "PER_PERIOD"
    let basis: String
}

nonisolated struct HourlyRow: Codable {
    let rate: Double
    /// Hours per pay period (backend multiplies by periodsPerYear).
    let regularHours: Double?
    let overtimeHours: Double?
    let overtimeMultiplier: Double?
    let doubleTimeHours: Double?
    let doubleTimeMultiplier: Double?
}

nonisolated struct CountryOptions: Codable {
    let US: USOptions?
    let UK: UKOptions?
}

nonisolated struct USOptions: Codable {
    let state: String
    let filingStatus: String
    let allowances: Int?
    let w4: W4?
}

nonisolated struct W4: Codable {
    let useOldW4: Bool?
    let nonresidentAlien: Bool?
    /// $2000 per qualifying child + $500 per other dependent.
    let dependentsAmount: Double?
    /// Annual non-job income (W-4 step 4(a)).
    let otherIncome: Double?
    /// Itemized deductions (W-4 step 4(b)). Overrides standard deduction if greater.
    let itemizedDeductions: Double?
    /// Additional federal withholding PER PAY PERIOD (W-4 step 4(c)).
    let additionalWithholding: Double?
    let exemptFederal: Bool?
    let exemptSocialSecurity: Bool?
    let exemptMedicare: Bool?
}

nonisolated struct UKOptions: Codable {
    let taxCode: String?
    let scottishResident: Bool?
    let niCategory: String?
}

nonisolated struct PreTaxDeductions: Codable {
    let pensionPercent: Double?
    /// Catch-all fixed annual amount (still supported for back-compat).
    let fixed: Double?
    let hsa: Double?
    let medical: Double?
    let dental: Double?
    let vision: Double?
    let healthcareFsa: Double?
    let dependentCareFsa: Double?
    /// Named custom deductions; each becomes its own line item in the response.
    let customDeductions: [NamedDeduction]?
}

nonisolated struct NamedDeduction: Codable {
    let name: String
    let amount: Double
}

nonisolated struct PostTaxDeductions: Codable {
    let fixed: Double?
    /// Roth 401(k) percent of regular wages (0–1).
    let roth401kPercent: Double?
    let studentLoanPlan: String?
}

// MARK: - API Response Models

nonisolated struct SalaryCalculationResponse: Codable {
    let calculationId: String
    let grossPerCadence: Double
    /// Authoritative base-salary slice of gross per cadence (server-truth).
    let baseSalaryPerCadence: Double?
    /// Authoritative bonus slice of gross per cadence (server-truth).
    let bonusPerCadence: Double?
    let netPerCadence: Double
    let currency: String
    let rulePackVersion: String
    let lineItems: [LineItem]
    let explanation: [ExplanationItem]
}

nonisolated struct LineItem: Codable {
    let name: String
    let amount: Double
    /// EARNINGS, TAX_FEDERAL, TAX_FICA, TAX_STATE, PRE_TAX_BENEFIT, RETIREMENT, POST_TAX, NET.
    /// May be nil on legacy or untagged items.
    let category: String?
}

nonisolated struct ExplanationItem: Codable {
    let id: String
    let text: String
}

// MARK: - Benefits Input
// Not sent to the API as individual fields — combined into pretax.fixed.
// Tracked locally so the results screen can display individual line items.
nonisolated struct BenefitsInput {
    var medicalPremium: Double = 0       // Annual
    var dentalPremium: Double = 0        // Annual
    var lifeInsurancePremium: Double = 0 // Annual
}

// MARK: - View-Friendly Models

nonisolated struct ViewFriendlyResponse {
    let grossPay: GrossPayDetails
    let taxes: Taxes
    let benefits: BenefitsBreakdown
    let netPay: NetPay
    let currency: String
    let calculationId: String
    let rulePackVersion: String
    /// Raw API line items, per-cadence, with category tags. Used by the donut + itemized summary.
    let lineItems: [LineItem]
}

nonisolated struct GrossPayDetails {
    let baseSalaryPerPeriod: Double
    let bonusPerPeriod: Double
    let totalPerPeriod: Double
    let annualTotal: Double
    /// Full annual bonus as a one-time lump sum (not spread per period).
    /// Drives the standalone "one-time bonus" card on the Insights screen.
    let annualBonus: Double
    let payFrequency: String
}

nonisolated struct BenefitsBreakdown {
    let medical: Double
    let dental: Double
    let retirement401k: Double
    let lifeInsurance: Double
    var total: Double { medical + dental + retirement401k + lifeInsurance }
}

nonisolated struct Taxes {
    let federal: TaxBreakdown?
    let stateTax: TaxBreakdown?
    /// Social Security + Medicare combined for the FICA display row.
    let ficaCombined: Double
    let socialSecurity: TaxBreakdown?
    let medicare: TaxBreakdown?
    let totalTaxes: Double
    let effectiveTaxRate: Double
}

nonisolated struct TaxBreakdown {
    let amount: Double
    let rate: Double?
    let description: String
}

nonisolated struct NetPay {
    let perPayPeriod: Double
    let annual: Double
    let takeHomePercentage: Double
}

// MARK: - Service

class SalaryCalculatorService {
    private var baseURL: String { AppConfig.apiBaseURL }

    /// Closure invoked on every request to fetch the current session token, if any.
    /// Injected so the service stays decoupled from the AccountManager type.
    var sessionTokenProvider: () -> String? = { nil }

    enum APIError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case decodingError(Error)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:           return "Invalid API URL"
            case .networkError(let e):  return "Network error: \(e.localizedDescription)"
            case .invalidResponse:      return "Invalid response from server"
            case .decodingError(let e): return "Failed to decode response: \(e.localizedDescription)"
            case .serverError(let m):   return m
            }
        }
    }

    struct StateEntry: Codable, Identifiable, Hashable {
        let code: String
        let name: String
        var id: String { code }
    }

    func fetchUSStates() async throws -> [StateEntry] {
        guard let url = URL(string: "\(baseURL)/v1/countries/US/states") else {
            throw APIError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode([StateEntry].self, from: data)
    }

    func calculateSalary(
        request: SalaryCalculationRequest,
        baseSalaryAnnual: Double,
        bonusAnnual: Double,
        benefits: BenefitsInput
    ) async throws -> ViewFriendlyResponse {
        guard let url = URL(string: "\(baseURL)/v1/calculate") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = sessionTokenProvider(), !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw APIError.networkError(error)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Server returned \(httpResponse.statusCode)"
            throw APIError.serverError(message)
        }

        let apiResponse: SalaryCalculationResponse
        do {
            apiResponse = try JSONDecoder().decode(SalaryCalculationResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }

        return transformToViewFriendly(
            apiResponse: apiResponse,
            originalRequest: request,
            baseSalaryAnnual: baseSalaryAnnual,
            bonusAnnual: bonusAnnual,
            benefits: benefits
        )
    }

    // MARK: - Response Transformation

    private func transformToViewFriendly(
        apiResponse: SalaryCalculationResponse,
        originalRequest: SalaryCalculationRequest,
        baseSalaryAnnual: Double,
        bonusAnnual: Double,
        benefits: BenefitsInput
    ) -> ViewFriendlyResponse {
        let cadence = originalRequest.cadence ?? "ANNUAL"
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
            ? apiResponse.grossPerCadence
            : apiResponse.grossPerCadence * periodsPerYear
        let annualNet = periodsPerYear == 1
            ? apiResponse.netPerCadence
            : apiResponse.netPerCadence * periodsPerYear

        var federalTax: TaxBreakdown?
        var stateTax: TaxBreakdown?
        var socialSecurity: TaxBreakdown?
        var medicare: TaxBreakdown?
        var pension401k: Double = 0
        var totalTaxes: Double = 0

        for item in apiResponse.lineItems {
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

        return ViewFriendlyResponse(
            grossPay: GrossPayDetails(
                baseSalaryPerPeriod: apiResponse.baseSalaryPerCadence ?? (baseSalaryAnnual / periodsPerYear),
                bonusPerPeriod: apiResponse.bonusPerCadence ?? (bonusAnnual / periodsPerYear),
                totalPerPeriod: apiResponse.grossPerCadence,
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
                medical: benefits.medicalPremium / periodsPerYear,
                dental: benefits.dentalPremium / periodsPerYear,
                retirement401k: pension401k,
                lifeInsurance: benefits.lifeInsurancePremium / periodsPerYear
            ),
            netPay: NetPay(
                perPayPeriod: apiResponse.netPerCadence,
                annual: annualNet,
                takeHomePercentage: annualGross > 0 ? (annualNet / annualGross) * 100 : 0
            ),
            currency: apiResponse.currency,
            calculationId: apiResponse.calculationId,
            rulePackVersion: apiResponse.rulePackVersion,
            lineItems: apiResponse.lineItems
        )
    }
}
