//
//  EquityModels.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  DTOs for /v1/grants and /v1/stocks — mirror the backend's RsuGrant,
//  GrantListResponse, StockSymbol/StockSearchResponse, and StockQuote shapes.
//

import Foundation

nonisolated struct RsuGrant: Codable, Identifiable, Equatable {
    /// Server-assigned. Nil only on a not-yet-created grant.
    let id: String?
    /// Ticker symbol; nil for private companies entered manually.
    let ticker: String?
    let company: String?
    /// True when the price was entered manually rather than from a quote.
    let manualPrice: Bool?
    let sharesTotal: Double
    let pricePerShare: Double
    /// ISO-8601 yyyy-MM-dd.
    let grantDate: String
    let schedule: VestingSchedule

    nonisolated struct VestingSchedule: Codable, Equatable {
        /// Client preset id: annual4, monthly1cliff, quarterly1cliff, custom.
        let presetId: String?
        let totalMonths: Int
        let cliffMonths: Int
        let freqMonths: Int
    }
}

/// The schedule presets offered in the grant form (§C). Raw values are the
/// presetId strings persisted on the backend.
nonisolated enum VestingPreset: String, CaseIterable, Identifiable {
    case annual4
    case monthly1cliff
    case quarterly1cliff
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .annual4:         return "4-year annual (25/25/25/25)"
        case .monthly1cliff:   return "4-year monthly, 1-year cliff"
        case .quarterly1cliff: return "4-year quarterly, 1-year cliff"
        case .custom:          return "Custom"
        }
    }

    /// Preset terms; nil for .custom (user supplies their own).
    var terms: (totalMonths: Int, cliffMonths: Int, freqMonths: Int)? {
        switch self {
        case .annual4:         return (48, 0, 12)
        case .monthly1cliff:   return (48, 12, 1)
        case .quarterly1cliff: return (48, 12, 3)
        case .custom:          return nil
        }
    }
}

nonisolated extension RsuGrant.VestingSchedule {
    /// Compact label for list rows: "4-yr monthly · 1-yr cliff".
    var label: String {
        let years = totalMonths % 12 == 0 ? "\(totalMonths / 12)-yr" : "\(totalMonths)-mo"
        let cadence: String
        switch freqMonths {
        case 1:  cadence = "monthly"
        case 3:  cadence = "quarterly"
        case 12: cadence = "annual"
        default: cadence = "every \(freqMonths) mo"
        }
        let cliff = cliffMonths > 0
            ? " · \(cliffMonths % 12 == 0 ? "\(cliffMonths / 12)-yr" : "\(cliffMonths)-mo") cliff"
            : ""
        return "\(years) \(cadence)\(cliff)"
    }
}

nonisolated struct GrantListResponse: Codable {
    let items: [RsuGrant]
}

nonisolated struct StockSymbol: Codable, Identifiable, Equatable {
    let symbol: String
    let name: String
    var id: String { symbol }
}

nonisolated struct StockSearchResponse: Codable {
    let items: [StockSymbol]
}

nonisolated struct StockQuote: Codable, Equatable {
    let symbol: String
    let price: Double
    /// ISO-8601 instant of the underlying trade.
    let asOf: String
}
