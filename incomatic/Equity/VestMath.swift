//
//  VestMath.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  Pure vest-distribution math shared by the vest timeline, the Equity card
//  headline, and the yearly earnings outlook. Ported from the Claude Design
//  prototype (rsu-shared.jsx: buildVestEvents / groupEventsByYear).
//
//  Shares vest proportionally to months covered: the cliff releases
//  cliffMonths/totalMonths of the grant at once, then a slice every freqMonths
//  until totalMonths. All valuation uses the grant's stored pricePerShare —
//  "today's price for every future vest".
//

import Foundation

nonisolated enum VestMath {

    struct VestEvent: Equatable {
        let date: Date
        let shares: Double
        let isCliff: Bool
    }

    struct YearGroup: Identifiable, Equatable {
        let year: Int
        let shares: Double
        let value: Double
        let vestCount: Int
        let hasCliff: Bool
        var id: Int { year }
    }

    static func vestEvents(for grant: RsuGrant, calendar: Calendar = .current) -> [VestEvent] {
        guard let start = parseDate(grant.grantDate, calendar: calendar) else { return [] }
        let total = max(1, grant.schedule.totalMonths)
        let cliff = max(0, min(grant.schedule.cliffMonths, total))
        let freq = max(1, grant.schedule.freqMonths)
        let sharesPerMonth = grant.sharesTotal / Double(total)

        var events: [VestEvent] = []
        var coveredMonths = cliff
        if cliff > 0 {
            events.append(VestEvent(
                date: addMonths(cliff, to: start, calendar: calendar),
                shares: sharesPerMonth * Double(cliff),
                isCliff: true
            ))
        }
        while coveredMonths < total {
            let next = min(coveredMonths + freq, total)
            events.append(VestEvent(
                date: addMonths(next, to: start, calendar: calendar),
                shares: sharesPerMonth * Double(next - coveredMonths),
                isCliff: false
            ))
            coveredMonths = next
        }
        return events
    }

    /// Year-level rollup of a single grant's events, ascending by year.
    static func yearGroups(for grant: RsuGrant, calendar: Calendar = .current) -> [YearGroup] {
        let events = vestEvents(for: grant, calendar: calendar)
        let byYear = Dictionary(grouping: events) { calendar.component(.year, from: $0.date) }
        return byYear.keys.sorted().map { year in
            let group = byYear[year] ?? []
            let shares = group.reduce(0) { $0 + $1.shares }
            return YearGroup(
                year: year,
                shares: shares,
                value: shares * grant.pricePerShare,
                vestCount: group.count,
                hasCliff: group.contains { $0.isCliff }
            )
        }
    }

    /// Dollar value vesting in `year` across all grants (each at its stored price).
    static func value(inYear year: Int, grants: [RsuGrant], calendar: Calendar = .current) -> Double {
        var total = 0.0
        for grant in grants {
            let shares = vestEvents(for: grant, calendar: calendar)
                .filter { calendar.component(.year, from: $0.date) == year }
                .reduce(0.0) { $0 + $1.shares }
            total += shares * grant.pricePerShare
        }
        return total
    }

    /// Next vest strictly after `date` across the grant's events.
    static func nextVest(for grant: RsuGrant, after date: Date = Date(), calendar: Calendar = .current) -> VestEvent? {
        vestEvents(for: grant, calendar: calendar).first { $0.date > date }
    }

    /// Last calendar year in which any grant still vests. Nil when no grants.
    static func finalVestYear(grants: [RsuGrant], calendar: Calendar = .current) -> Int? {
        grants.compactMap { grant in
            vestEvents(for: grant, calendar: calendar).last.map { calendar.component(.year, from: $0.date) }
        }.max()
    }

    static func parseDate(_ isoDate: String, calendar: Calendar = .current) -> Date? {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: isoDate)
    }

    private static func addMonths(_ months: Int, to date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }
}
