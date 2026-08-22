//
//
//  PaydayInfo.swift
//  incomatic
//
//  Created by Ben Makusha on 08/14/2026
//
//  All countdown math lives here so the app and the widget extension cannot
//  drift. Both call `PaydayCalculator.info(...)` and nothing else.
//

import Foundation

/// The resolved answer to "when is the next payday, and what lands".
nonisolated struct PaydayInfo: Equatable {
    /// True for `varies` anchors. Every surface that shows an approximate
    /// result has to say so — being vague and admitting it beats being precise
    /// and wrong.
    let approximate: Bool
    /// The date after weekend and holiday adjustment. This is the one to show.
    let date: Date
    /// The date the schedule produced before adjustment, kept so the UI can
    /// explain the move rather than silently showing a different day.
    let rawDate: Date
    let shifted: Bool
    let shiftedFrom: Date?
    let daysAway: Int
    let net: Double
    let justPaid: Bool

    /// Whether there is a figure worth showing.
    ///
    /// Zero is the stored default, not a calculated result: `recordNet` only
    /// ever writes a positive figure, so a zero means the app has never worked
    /// one out on this install. That is the normal state for the entire
    /// install base on upgrade, because the Calculator banner asks for a payday
    /// without requiring a calculation first. Rendering it as "$0" would put a
    /// wrong number on the Lock Screen for exactly the users the loop is trying
    /// to win back, so every surface shows the countdown without the amount
    /// instead.
    var hasNet: Bool { net > 0 }
}

nonisolated enum PaydayCalculator {

    // MARK: - Entry point

    /// The only function the countdown, the widget and the notification
    /// scheduler call. Returns nil when there is no usable anchor, which is the
    /// empty state rather than an error.
    static func info(for anchor: PayAnchor?,
                     net: Double,
                     now: Date = Date(),
                     calendar: Calendar = .current) -> PaydayInfo? {
        guard let anchor, anchor.isComplete else { return nil }
        let today = calendar.startOfDay(for: now)

        if anchor.kind == .varies {
            guard let lastPaid = anchor.lastPaid else { return nil }
            let step = approximateStep(for: anchor.frequency)
            let estimate = calendar.date(byAdding: .day,
                                         value: step,
                                         to: calendar.startOfDay(for: lastPaid)) ?? today
            let days = calendar.dateComponents([.day], from: today, to: estimate).day ?? 0
            return PaydayInfo(
                approximate: true,
                date: estimate,
                rawDate: estimate,
                shifted: false,
                shiftedFrom: nil,
                daysAway: max(0, days),
                net: net,
                // A varies anchor cannot know it was paid, so treat the two days
                // after the estimate as "just paid" rather than counting to a
                // date that has already gone by.
                justPaid: days <= 0 && days > -3
            )
        }

        guard let raw = rawNextPayday(anchor: anchor, from: today, calendar: calendar) else { return nil }
        let shift = applyShift(raw, rule: anchor.shiftRule, calendar: calendar)
        let daysAway = calendar.dateComponents([.day], from: today, to: shift.date).day ?? 0
        return PaydayInfo(
            approximate: false,
            date: shift.date,
            rawDate: raw,
            shifted: shift.shifted,
            shiftedFrom: shift.from,
            daysAway: daysAway,
            net: net,
            justPaid: daysAway == 0
        )
    }

    // MARK: - Schedule

    /// Days between paychecks for an interval schedule.
    private static func intervalStep(for frequency: PayFrequency) -> Int {
        switch frequency {
        case .daily:  return 1
        case .weekly: return 7
        default:      return 14
        }
    }

    /// Rough spacing used only for `varies`, where by definition there is no
    /// real schedule to follow.
    private static func approximateStep(for frequency: PayFrequency) -> Int {
        switch frequency {
        case .daily:       return 1
        case .weekly:      return 7
        case .semiMonthly: return 15
        case .monthly:     return 30
        case .quarterly:   return 91
        case .semiAnnual:  return 182
        case .annual:      return 365
        case .biweekly:    return 14
        }
    }

    /// The next payday on or after `from`, before weekend and holiday shifting.
    static func rawNextPayday(anchor: PayAnchor,
                              from: Date,
                              calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: from)

        switch anchor.kind {
        case .interval:
            guard let lastPaid = anchor.lastPaid else { return nil }
            let step = intervalStep(for: anchor.frequency)
            var date = calendar.date(byAdding: .day,
                                     value: step,
                                     to: calendar.startOfDay(for: lastPaid)) ?? today
            // Guarded rather than `while true`: a corrupt anchor with a date far
            // in the past should return nil, not spin.
            var guardCount = 0
            while date < today && guardCount < 4000 {
                date = calendar.date(byAdding: .day, value: step, to: date) ?? date
                guardCount += 1
            }
            return date < today ? nil : date

        case .dayOfMonth:
            // Numbered days ascending, "last" always after them: the last day of
            // a month is never earlier than a numbered day in the same month.
            let sorted = anchor.days.sorted { a, b in
                switch (a, b) {
                case (.day(let x), .day(let y)): return x < y
                case (.day, .last):              return true
                case (.last, .day):              return false
                case (.last, .last):             return false
                }
            }
            // Three months of lookahead covers every cadence this shape serves
            // except quarterly and rarer, which get a wider window.
            let horizon = anchor.frequency == .semiMonthly || anchor.frequency == .monthly ? 3 : 14
            for offset in 0..<horizon {
                guard let probe = calendar.date(byAdding: .month, value: offset,
                                                to: startOfMonth(today, calendar: calendar)) else { continue }
                let lastDay = daysInMonth(probe, calendar: calendar)
                for entry in sorted {
                    let dom: Int
                    switch entry {
                    case .last:       dom = lastDay
                    // Clamp rather than roll into the next month: someone paid on
                    // the 31st is paid on the 28th in February, not on March 3rd.
                    case .day(let d): dom = min(d, lastDay)
                    }
                    var components = calendar.dateComponents([.year, .month], from: probe)
                    components.day = dom
                    guard let candidate = calendar.date(from: components) else { continue }
                    if candidate >= today { return candidate }
                }
            }
            return nil

        case .varies:
            return nil
        }
    }

    // MARK: - Weekend and holiday shifting

    struct ShiftResult {
        let date: Date
        let shifted: Bool
        let from: Date?
    }

    /// Walks off a non-banking day in the direction the user's employer pays.
    static func applyShift(_ date: Date,
                           rule: PayShiftRule,
                           calendar: Calendar = .current) -> ShiftResult {
        guard rule != .exact else { return ShiftResult(date: date, shifted: false, from: nil) }
        var candidate = date
        var guardCount = 0
        while isNonBanking(candidate, calendar: calendar) && guardCount < 10 {
            candidate = calendar.date(byAdding: .day,
                                      value: rule == .after ? 1 : -1,
                                      to: candidate) ?? candidate
            guardCount += 1
        }
        let moved = candidate != date
        return ShiftResult(date: candidate, shifted: moved, from: moved ? date : nil)
    }

    /// Weekend or US federal holiday. ACH does not settle on either, which is
    /// what actually moves a direct deposit.
    static func isNonBanking(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 { return true }
        return USFederalHolidays.isObservedHoliday(date, calendar: calendar)
    }

    // MARK: - Presentation helpers

    /// Elapsed share of the pay period, so the ring fills as payday approaches.
    static func periodProgress(_ info: PaydayInfo?, frequency: PayFrequency) -> Double {
        guard let info else { return 0 }
        let span: Double
        switch frequency {
        case .daily:       span = 1
        case .weekly:      span = 7
        case .semiMonthly: span = 15
        case .monthly:     span = 30
        case .quarterly:   span = 91
        case .semiAnnual:  span = 182
        case .annual:      span = 365
        case .biweekly:    span = 14
        }
        return min(1, max(0.04, (span - Double(info.daysAway)) / span))
    }

    /// Countdown phrasing. VoiceOver reads this same string, so it has to be a
    /// sentence someone would say out loud rather than "3 d".
    static func countdownText(_ info: PaydayInfo?) -> String {
        guard let info else { return "No payday set" }
        if info.justPaid { return "Payday" }
        switch info.daysAway {
        case 1:  return "Tomorrow"
        case 2:  return "In 2 days"
        default: return "In \(info.daysAway) days"
        }
    }

    static func countdownShort(_ info: PaydayInfo?) -> String {
        guard let info else { return "--" }
        return info.justPaid ? "Today" : "\(info.daysAway)d"
    }

    // MARK: - Calendar helpers

    private static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    static func daysInMonth(_ date: Date, calendar: Calendar = .current) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }
}

// MARK: - Holidays

/// US federal holidays, computed rather than listed.
///
/// The design prototype carried a hardcoded list of 2026 dates, which is correct
/// for exactly one year and then silently wrong. These are all rule-based, so
/// deriving them costs little and does not expire.
nonisolated enum USFederalHolidays {

    /// True when `date` is a federal holiday as observed by banks — which is
    /// what matters, since a Saturday holiday closes the Fed on the Friday.
    static func isObservedHoliday(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: day)
        return observed(in: year, calendar: calendar).contains(day)
            // A holiday in the first days of January can be observed in the
            // previous December, and vice versa.
            || observed(in: year - 1, calendar: calendar).contains(day)
            || observed(in: year + 1, calendar: calendar).contains(day)
    }

    private static func observed(in year: Int, calendar: Calendar) -> Set<Date> {
        var result: Set<Date> = []

        // Fixed-date holidays shift to the nearest weekday when they land on a
        // weekend: Saturday is observed Friday, Sunday is observed Monday.
        for (month, day) in [(1, 1), (6, 19), (7, 4), (11, 11), (12, 25)] {
            guard let date = date(year: year, month: month, day: day, calendar: calendar) else { continue }
            result.insert(observedWeekday(for: date, calendar: calendar))
        }

        // Nth-weekday holidays already fall on a Monday or Thursday, so they
        // never shift.
        let weekdayRules: [(month: Int, weekday: Int, ordinal: Int)] = [
            (1, 2, 3),    // MLK Day, third Monday of January
            (2, 2, 3),    // Washington's Birthday, third Monday of February
            (9, 2, 1),    // Labor Day, first Monday of September
            (10, 2, 2),   // Columbus Day, second Monday of October
            (11, 5, 4),   // Thanksgiving, fourth Thursday of November
        ]
        for rule in weekdayRules {
            if let date = nthWeekday(rule.ordinal, weekday: rule.weekday,
                                     month: rule.month, year: year, calendar: calendar) {
                result.insert(date)
            }
        }

        // Memorial Day is the last Monday of May, which is the only "last"
        // rule in the set.
        if let date = lastWeekday(2, month: 5, year: year, calendar: calendar) {
            result.insert(date)
        }

        return result
    }

    private static func observedWeekday(for date: Date, calendar: Calendar) -> Date {
        switch calendar.component(.weekday, from: date) {
        case 7:  return calendar.date(byAdding: .day, value: -1, to: date) ?? date  // Saturday
        case 1:  return calendar.date(byAdding: .day, value: 1, to: date) ?? date   // Sunday
        default: return date
        }
    }

    private static func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    private static func nthWeekday(_ ordinal: Int, weekday: Int, month: Int, year: Int,
                                   calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = ordinal
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    private static func lastWeekday(_ weekday: Int, month: Int, year: Int,
                                    calendar: Calendar) -> Date? {
        // weekdayOrdinal = -1 means "last of the month" to DateComponents.
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = -1
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }
}
