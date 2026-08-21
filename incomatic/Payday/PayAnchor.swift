//
//
//  PayAnchor.swift
//  incomatic
//
//  Created by Ben Makusha on 08/14/2026
//
//  The one new piece of user data Phase 1 introduces: when the money actually
//  lands. Everything in the payday loop — countdown, widget, notification — is
//  fiction without it, because the app has never asked before.
//

import Foundation

/// How a pay schedule repeats.
///
/// Semi-monthly and monthly are day-of-month **rules**, not intervals. Modelling
/// "the 15th and the last day" as "every 15 days" drifts within two months and
/// then keeps drifting, so they get their own shape rather than an approximation
/// that looks right in testing and is wrong by March.
nonisolated enum PayAnchorKind: String, Codable, Equatable {
    /// Repeats from a known date. Weekly and bi-weekly.
    case interval
    /// Lands on set days of the month. Semi-monthly and monthly.
    case dayOfMonth
    /// Genuinely irregular. Produces an approximate countdown, labelled as one.
    case varies
}

/// What an employer does when payday falls on a weekend or a bank holiday.
///
/// Most US employers pay early, so `before` is the default — but it is a
/// per-employer fact, not a rule we can assert, so the user can correct it.
nonisolated enum PayShiftRule: String, Codable, Equatable, CaseIterable {
    case before
    case after
    case exact

    var label: String {
        switch self {
        case .before: return "The Friday before"
        case .after:  return "The Monday after"
        case .exact:  return "That exact day"
        }
    }
}

/// A day within a month. `last` is a first-class case rather than 31 because
/// "the last day of the month" is the most common monthly arrangement and
/// cannot be written as a number that survives February.
nonisolated enum MonthDay: Codable, Equatable, Hashable {
    case day(Int)
    case last

    var label: String {
        switch self {
        case .day(let d): return Self.ordinal(d)
        case .last:       return "Last day"
        }
    }

    static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1):       suffix = "st"
        case (_, 2):       suffix = "nd"
        case (_, 3):       suffix = "rd"
        default:           suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    // Encoded as either an Int or the string "last" so the payload stays
    // readable in UserDefaults and in the app group the widget reads.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let n = try? container.decode(Int.self) {
            self = .day(n)
        } else {
            let s = try container.decode(String.self)
            self = s == "last" ? .last : .day(Int(s) ?? 1)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .day(let n): try container.encode(n)
        case .last:       try container.encode("last")
        }
    }
}

/// When the user gets paid. One persisted object, shared with the widget
/// extension through the app group.
nonisolated struct PayAnchor: Codable, Equatable {
    var kind: PayAnchorKind
    var frequency: PayFrequency

    /// `interval` only: the most recent payday we count forward from.
    var lastPaid: Date?

    /// `dayOfMonth` only: one day for monthly, two for semi-monthly.
    var days: [MonthDay]

    var shiftRule: PayShiftRule

    init(kind: PayAnchorKind,
         frequency: PayFrequency,
         lastPaid: Date? = nil,
         days: [MonthDay] = [],
         shiftRule: PayShiftRule = .before) {
        self.kind = kind
        self.frequency = frequency
        self.lastPaid = lastPaid
        self.days = days
        self.shiftRule = shiftRule
    }

    /// Which capture UI a cadence needs. Semi-monthly and monthly are rules;
    /// everything else counts forward from a date.
    static func shape(for frequency: PayFrequency) -> PayAnchorKind {
        switch frequency {
        case .semiMonthly, .monthly, .quarterly, .semiAnnual, .annual:
            return .dayOfMonth
        case .daily, .weekly, .biweekly:
            return .interval
        }
    }

    /// A sensible starting value for the editor, given only the cadence.
    static func draft(for frequency: PayFrequency) -> PayAnchor {
        switch shape(for: frequency) {
        case .dayOfMonth:
            return PayAnchor(kind: .dayOfMonth,
                             frequency: frequency,
                             days: frequency == .semiMonthly ? [.day(15), .last] : [.last])
        default:
            return PayAnchor(kind: .interval, frequency: frequency)
        }
    }

    /// True when the anchor has enough information to produce a date.
    var isComplete: Bool {
        switch kind {
        case .interval:   return lastPaid != nil
        case .dayOfMonth: return !days.isEmpty
        case .varies:     return lastPaid != nil
        }
    }
}
