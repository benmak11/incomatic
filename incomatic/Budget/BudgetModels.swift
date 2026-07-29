//
//  BudgetModels.swift
//  incomatic
//
//  Created by Ben Makusha on 07/22/2026
//
//  DTOs for /v1/budget — mirror the backend's Budget/SavingsGoal/Expense
//  shapes exactly. The three enums are wire-format UPPER_SNAKE_CASE
//  (app.salary.common.constants.GoalType/ExpenseCadence/BudgetBucket), so
//  they get custom Codable via `apiValue` rather than relying on the default
//  raw-value encoding, matching the PayFrequency/FilingStatus convention.
//

import Foundation

nonisolated enum GoalType: String, CaseIterable, Codable, Identifiable {
    case emergencyFund, vacation, homeDownPayment, debtPayoff, car, wedding, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .emergencyFund:   return "Emergency fund"
        case .vacation:        return "Vacation"
        case .homeDownPayment: return "Home"
        case .debtPayoff:      return "Debt payoff"
        case .car:              return "Car"
        case .wedding:          return "Wedding"
        case .custom:            return "Custom"
        }
    }

    var apiValue: String {
        switch self {
        case .emergencyFund:   return "EMERGENCY_FUND"
        case .vacation:        return "VACATION"
        case .homeDownPayment: return "HOME_DOWN_PAYMENT"
        case .debtPayoff:      return "DEBT_PAYOFF"
        case .car:              return "CAR"
        case .wedding:          return "WEDDING"
        case .custom:            return "CUSTOM"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let match = Self.allCases.first(where: { $0.apiValue == raw }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown GoalType: \(raw)")
        }
        self = match
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(apiValue)
    }
}

nonisolated enum ExpenseCadence: String, CaseIterable, Codable, Identifiable {
    case weekly, biweekly, semiMonthly, monthly, quarterly, annual, oneTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly:      return "Weekly"
        case .biweekly:    return "Biweekly"
        case .semiMonthly: return "Semi-monthly"
        case .monthly:     return "Monthly"
        case .quarterly:   return "Quarterly"
        case .annual:      return "Annual"
        case .oneTime:     return "One-time"
        }
    }

    /// Occurrences per year this cadence produces, used by `BudgetEngine`
    /// to spread an amount across paycheck periods.
    var occurrencesPerYear: Double {
        switch self {
        case .weekly:      return 52
        case .biweekly:    return 26
        case .semiMonthly: return 24
        case .monthly:     return 12
        case .quarterly:   return 4
        case .annual:      return 1
        case .oneTime:     return 1
        }
    }

    var apiValue: String {
        switch self {
        case .weekly:      return "WEEKLY"
        case .biweekly:    return "BIWEEKLY"
        case .semiMonthly: return "SEMI_MONTHLY"
        case .monthly:     return "MONTHLY"
        case .quarterly:   return "QUARTERLY"
        case .annual:      return "ANNUAL"
        case .oneTime:     return "ONE_TIME"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let match = Self.allCases.first(where: { $0.apiValue == raw }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown ExpenseCadence: \(raw)")
        }
        self = match
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(apiValue)
    }
}

/// 50/30/20-style categorization, matching the backend's bucket semantics.
nonisolated enum BudgetBucket: String, CaseIterable, Codable, Identifiable {
    case needs, wants, savings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .needs:   return "Needs"
        case .wants:   return "Wants"
        case .savings: return "Savings"
        }
    }

    var apiValue: String {
        switch self {
        case .needs:   return "NEEDS"
        case .wants:   return "WANTS"
        case .savings: return "SAVINGS"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let match = Self.allCases.first(where: { $0.apiValue == raw }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown BudgetBucket: \(raw)")
        }
        self = match
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(apiValue)
    }
}

/// A savings goal within the household budget. `id` is client-assigned
/// (stable identity for local list management) — the server stores whatever
/// is sent and never validates it, so a freshly-created goal gets a local
/// UUID string before the first save.
nonisolated struct SavingsGoal: Codable, Identifiable, Equatable {
    var id: String
    var type: GoalType
    var name: String
    var targetAmount: Double
    /// ISO-8601 yyyy-MM-dd, optional.
    var targetDate: String?
    /// Lower resolves funding contention first.
    var priority: Int
    var currentSaved: Double = 0

    init(
        id: String = UUID().uuidString,
        type: GoalType,
        name: String,
        targetAmount: Double,
        targetDate: String? = nil,
        priority: Int,
        currentSaved: Double = 0
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.priority = priority
        self.currentSaved = currentSaved
    }
}

/// An itemized expense within the household budget. Id is client-assigned,
/// same as `SavingsGoal`.
nonisolated struct Expense: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var amount: Double
    var cadence: ExpenseCadence
    var bucket: BudgetBucket
    /// ISO-8601 yyyy-MM-dd, optional — day-of-month/day-of-week this recurs on.
    var dueDate: String?
    var category: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        amount: Double,
        cadence: ExpenseCadence,
        bucket: BudgetBucket,
        dueDate: String? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.cadence = cadence
        self.bucket = bucket
        self.dueDate = dueDate
        self.category = category
    }
}

/// A signed-in user's single household budget — savings goals + itemized
/// expenses. One per user; `PUT /v1/budget` replaces the whole object.
nonisolated struct Budget: Codable, Equatable {
    var goals: [SavingsGoal] = []
    var expenses: [Expense] = []
}

/// A dated, already-net-of-tax lump sum feeding `POST /v1/budget/plan` and
/// `BudgetEngine` — sourced from `CalculateResponse.supplemental.net` (bonus)
/// or a `VestMath` vest event's dollar value (RSU), never a re-derived flat
/// tax-rate estimate.
nonisolated struct Windfall: Codable, Equatable {
    var label: String
    var netAmount: Double
    /// ISO-8601 yyyy-MM-dd.
    var date: String
}

/// Mirrors the backend's `POST /v1/budget/plan` response — Gemini's
/// suggested per-goal contribution rate + rationale. `BudgetEngine` treats
/// `goalContributions` as an override on top of its own default waterfall,
/// still capped by what a paycheck can actually afford.
nonisolated struct GoalContribution: Codable, Equatable {
    let goalId: String
    let suggestedPerPeriodAmount: Double
}

nonisolated struct BudgetPlan: Codable, Equatable {
    let rationale: String
    var goalContributions: [GoalContribution] = []
    var warnings: [String] = []
}

nonisolated struct BudgetPlanRequest: Codable {
    var budget: Budget
    /// `PayFrequency.apiValue` — same request-only convention as
    /// `CalculationRequestBuilder`'s `cadence`/`filingStatus` fields;
    /// `PayFrequency` itself isn't `Codable`.
    var payFrequency: String
    var netIncomePerPeriod: Double
    var windfalls: [Windfall] = []
}
