//
//  SavedSession.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Wire types for the calculation-history endpoints. These mirror the backend
//  DTOs (SavedCalculationSummary, SavedCalculationDetail, CalculationListResponse).
//

import Foundation

struct SavedCalculationSummary: Codable, Identifiable, Hashable {
    let id: String
    let savedAt: String
    let country: String?
    let taxYear: Int?
    let cadence: String?
    let stateCode: String?
    let stateName: String?
    let currency: String?
    let takeHomePerPeriod: Double?
    let taxesPerPeriod: Double?
    let benefitsPerPeriod: Double?
    let grossPerPeriod: Double?
    let takeHomePct: Double?
}

struct CalculationListResponse: Codable {
    let items: [SavedCalculationSummary]
    let nextCursor: String?
}

struct SavedCalculationDetail: Codable {
    let summary: SavedCalculationSummary
    let request: SalaryCalculationRequest
    let response: SalaryCalculationResponse
}

extension SavedCalculationSummary {
    /// Local user-facing label for the row header (state name when US, country name otherwise).
    var displayTitle: String {
        if let name = stateName, !name.isEmpty { return name }
        if let code = stateCode, !code.isEmpty { return code }
        return country ?? "Calculation"
    }

    /// Friendly subtitle like "United States · Bi-weekly".
    var displaySubtitle: String {
        let countryLabel = (country == "US") ? "United States" : (country ?? "")
        let cadenceLabel = cadenceFriendly
        return [countryLabel, cadenceLabel].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Compact savedAt label like "Jun 7" or "Jun 7, 2026". Falls back to the raw
    /// ISO string when parsing fails.
    var savedAtCompact: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = iso.date(from: savedAt) ?? ISO8601DateFormatter().date(from: savedAt)
        guard let date = parsed else { return savedAt }
        let fmt = DateFormatter()
        fmt.locale = .current
        let now = Date()
        let sameYear = Calendar.current.isDate(date, equalTo: now, toGranularity: .year)
        fmt.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        return fmt.string(from: date)
    }

    private var cadenceFriendly: String {
        switch (cadence ?? "").uppercased() {
        case "DAILY":       return "Daily"
        case "WEEKLY":      return "Weekly"
        case "BIWEEKLY":    return "Bi-weekly"
        case "SEMIMONTHLY": return "Semi-monthly"
        case "MONTHLY":     return "Monthly"
        case "QUARTERLY":   return "Quarterly"
        case "SEMIANNUAL":  return "Semi-annual"
        case "ANNUAL":      return "Annual"
        default:            return cadence?.capitalized ?? ""
        }
    }
}
