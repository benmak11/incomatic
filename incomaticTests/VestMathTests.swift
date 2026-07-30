//
//  VestMathTests.swift
//  incomaticTests
//
//  VestMath is pure calculation logic (vest-event distribution, year rollups,
//  cross-grant value totals) — covers the cliff/no-cliff split, multi-grant
//  aggregation, and the boundary behaviors (nextVest past the end, empty
//  grant lists, unparseable dates) that the vest timeline/outlook UI relies on.
//

import XCTest
@testable import Incomatic

final class VestMathTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func grant(
        shares: Double,
        price: Double = 10,
        grantDate: String,
        total: Int,
        cliff: Int,
        freq: Int
    ) -> RsuGrant {
        RsuGrant(
            id: "g1", ticker: "ACME", company: "Acme Corp", manualPrice: false,
            sharesTotal: shares, pricePerShare: price, grantDate: grantDate,
            schedule: .init(presetId: "custom", totalMonths: total, cliffMonths: cliff, freqMonths: freq)
        )
    }

    func test_vestEvents_annualNoCliff_splitsIntoFourEqualYearlySlices() {
        let g = grant(shares: 4_000, grantDate: "2024-01-15", total: 48, cliff: 0, freq: 12)
        let events = VestMath.vestEvents(for: g, calendar: calendar)

        XCTAssertEqual(events.count, 4)
        XCTAssertTrue(events.allSatisfy { !$0.isCliff })
        for event in events {
            XCTAssertEqual(event.shares, 1_000, accuracy: 0.001)
        }
        XCTAssertEqual(calendar.component(.year, from: events[0].date), 2025)
        XCTAssertEqual(calendar.component(.year, from: events[3].date), 2028)
    }

    func test_vestEvents_monthlyWithCliff_cliffReleasesProRataThenMonthlySlices() {
        let g = grant(shares: 4_800, grantDate: "2024-01-15", total: 48, cliff: 12, freq: 1)
        let events = VestMath.vestEvents(for: g, calendar: calendar)

        // 1 cliff event (12 months' worth) + 36 monthly events to cover the remaining 36 months.
        XCTAssertEqual(events.count, 37)
        XCTAssertTrue(events[0].isCliff)
        XCTAssertEqual(events[0].shares, 1_200, accuracy: 0.001)
        XCTAssertTrue(events.dropFirst().allSatisfy { !$0.isCliff })
        XCTAssertEqual(events[1].shares, 100, accuracy: 0.001)

        let totalShares = events.reduce(0.0) { $0 + $1.shares }
        XCTAssertEqual(totalShares, 4_800, accuracy: 0.001, "every share should be accounted for across cliff + slices")
    }

    func test_vestEvents_unparseableGrantDate_returnsEmpty() {
        let g = grant(shares: 4_000, grantDate: "not-a-date", total: 48, cliff: 0, freq: 12)
        XCTAssertTrue(VestMath.vestEvents(for: g, calendar: calendar).isEmpty)
    }

    func test_yearGroups_combinesSameYearEventsAndComputesDollarValue() {
        // 6-month grant, quarterly freq -> vests land at +3mo and +6mo, both in 2024.
        let g = grant(shares: 1_200, price: 5, grantDate: "2024-01-01", total: 6, cliff: 0, freq: 3)
        let groups = VestMath.yearGroups(for: g, calendar: calendar)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].year, 2024)
        XCTAssertEqual(groups[0].shares, 1_200, accuracy: 0.001)
        XCTAssertEqual(groups[0].value, 6_000, accuracy: 0.001)
        XCTAssertEqual(groups[0].vestCount, 2)
        XCTAssertFalse(groups[0].hasCliff)
    }

    func test_value_sumsAcrossMultipleGrantsForGivenYear() {
        // g1: $10/share, 1,000 shares/yr vesting 2025-2028.
        let g1 = grant(shares: 4_000, price: 10, grantDate: "2024-01-15", total: 48, cliff: 0, freq: 12)
        // g2: $20/share, 1,000 shares/yr vesting 2026-2027.
        let g2 = grant(shares: 2_000, price: 20, grantDate: "2025-01-15", total: 24, cliff: 0, freq: 12)

        let total2026 = VestMath.value(inYear: 2026, grants: [g1, g2], calendar: calendar)
        XCTAssertEqual(total2026, 30_000, accuracy: 0.001, "g1's $10k + g2's $20k should both land in 2026")

        let total2029 = VestMath.value(inYear: 2029, grants: [g1, g2], calendar: calendar)
        XCTAssertEqual(total2029, 0, "no grant vests after 2028")
    }

    func test_nextVest_returnsFirstEventStrictlyAfterGivenDate() {
        let g = grant(shares: 4_000, grantDate: "2024-01-15", total: 48, cliff: 0, freq: 12)
        let events = VestMath.vestEvents(for: g, calendar: calendar)

        let next = VestMath.nextVest(for: g, after: events[0].date, calendar: calendar)
        XCTAssertEqual(next?.date, events[1].date)
    }

    func test_nextVest_afterFinalVest_returnsNil() {
        let g = grant(shares: 4_000, grantDate: "2024-01-15", total: 48, cliff: 0, freq: 12)
        let events = VestMath.vestEvents(for: g, calendar: calendar)
        XCTAssertNil(VestMath.nextVest(for: g, after: events.last!.date, calendar: calendar))
    }

    func test_finalVestYear_returnsMaxAcrossGrants_nilWhenNoGrants() {
        let g1 = grant(shares: 1_000, grantDate: "2024-01-15", total: 24, cliff: 0, freq: 12) // ends 2026
        let g2 = grant(shares: 1_000, grantDate: "2024-01-15", total: 48, cliff: 0, freq: 12) // ends 2028

        XCTAssertEqual(VestMath.finalVestYear(grants: [g1, g2], calendar: calendar), 2028)
        XCTAssertNil(VestMath.finalVestYear(grants: [], calendar: calendar))
    }

    func test_parseDate_acceptsIsoRejectsOtherFormats() {
        XCTAssertNotNil(VestMath.parseDate("2026-07-28", calendar: calendar))
        XCTAssertNil(VestMath.parseDate("07/28/2026", calendar: calendar))
        XCTAssertNil(VestMath.parseDate("", calendar: calendar))
    }
}
