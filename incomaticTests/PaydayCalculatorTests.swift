//
//
//  PaydayCalculatorTests.swift
//  incomaticTests
//
//  Created by Ben Makusha on 08/14/2026
//
//  The countdown math is shared verbatim with the widget extension, and a wrong
//  date here is wrong on someone's Home Screen for two weeks. These pin the
//  cases that are easy to get subtly wrong: weekend shifting, short months,
//  "last day of the month", and the approximate path.
//

import XCTest
@testable import Incomatic

final class PaydayCalculatorTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        // Pinned so a machine in another zone does not shift every date by a day.
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func date(_ iso: String) -> Date {
        let parts = iso.split(separator: "-").map { Int($0)! }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components)!
    }

    private func info(_ anchor: PayAnchor, on today: String, net: Double = 2412.68) -> PaydayInfo? {
        PaydayCalculator.info(for: anchor, net: net, now: date(today), calendar: calendar)
    }

    // MARK: - Interval schedules

    func test_biweekly_countsForwardFromTheLastPaycheck() {
        let anchor = PayAnchor(kind: .interval, frequency: .biweekly,
                               lastPaid: date("2026-08-01"), shiftRule: .exact)

        let result = info(anchor, on: "2026-08-11")

        // Aug 1 plus 14 days.
        XCTAssertEqual(result?.date, date("2026-08-15"))
        XCTAssertEqual(result?.daysAway, 4)
        XCTAssertEqual(result?.approximate, false)
    }

    func test_biweekly_paydayOnASaturdayMovesToTheFridayBefore() {
        let anchor = PayAnchor(kind: .interval, frequency: .biweekly,
                               lastPaid: date("2026-08-01"), shiftRule: .before)

        let result = info(anchor, on: "2026-08-11")

        // Aug 15 2026 is a Saturday, so the money lands Friday the 14th.
        XCTAssertEqual(result?.date, date("2026-08-14"))
        XCTAssertEqual(result?.rawDate, date("2026-08-15"))
        XCTAssertEqual(result?.shifted, true)
        XCTAssertEqual(result?.shiftedFrom, date("2026-08-15"))
        XCTAssertEqual(result?.daysAway, 3)
    }

    func test_shiftRuleAfterMovesForwardInstead() {
        let anchor = PayAnchor(kind: .interval, frequency: .biweekly,
                               lastPaid: date("2026-08-01"), shiftRule: .after)

        // Saturday the 15th, forward past Sunday, lands Monday the 17th.
        XCTAssertEqual(info(anchor, on: "2026-08-11")?.date, date("2026-08-17"))
    }

    func test_shiftRuleExactLeavesTheDateAlone() {
        let anchor = PayAnchor(kind: .interval, frequency: .biweekly,
                               lastPaid: date("2026-08-01"), shiftRule: .exact)

        let result = info(anchor, on: "2026-08-11")

        XCTAssertEqual(result?.date, date("2026-08-15"))
        XCTAssertEqual(result?.shifted, false)
    }

    func test_paydayToday_readsAsJustPaid() {
        // Aug 1 plus 14 is Aug 15; with .exact that is today.
        let anchor = PayAnchor(kind: .interval, frequency: .biweekly,
                               lastPaid: date("2026-08-01"), shiftRule: .exact)

        let result = info(anchor, on: "2026-08-15")

        XCTAssertEqual(result?.daysAway, 0)
        XCTAssertEqual(result?.justPaid, true)
        XCTAssertEqual(PaydayCalculator.countdownText(result), "Payday")
    }

    func test_weekly_stepsSevenDays() {
        let anchor = PayAnchor(kind: .interval, frequency: .weekly,
                               lastPaid: date("2026-08-03"), shiftRule: .exact)

        XCTAssertEqual(info(anchor, on: "2026-08-05")?.date, date("2026-08-10"))
    }

    func test_aStaleLastPaidStillAdvancesToTheFuture() {
        // Someone who set an anchor a year ago and did not open the app since.
        let anchor = PayAnchor(kind: .interval, frequency: .biweekly,
                               lastPaid: date("2025-01-03"), shiftRule: .exact)

        let result = info(anchor, on: "2026-08-11")

        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.date, date("2026-08-11"))
        XCTAssertLessThan(result!.daysAway, 14)
    }

    // MARK: - Day-of-month rules

    func test_semiMonthly_picksTheNextOfTheTwoDays() {
        let anchor = PayAnchor(kind: .dayOfMonth, frequency: .semiMonthly,
                               days: [.day(15), .last], shiftRule: .exact)

        XCTAssertEqual(info(anchor, on: "2026-08-11")?.date, date("2026-08-15"))
        // Past the 15th, the last day of the month is next.
        XCTAssertEqual(info(anchor, on: "2026-08-20")?.date, date("2026-08-31"))
        // Past both, roll into September.
        XCTAssertEqual(info(anchor, on: "2026-09-01")?.date, date("2026-09-15"))
    }

    func test_lastDayResolvesPerMonthRatherThanAsThirtyOne() {
        let anchor = PayAnchor(kind: .dayOfMonth, frequency: .monthly,
                               days: [.last], shiftRule: .exact)

        XCTAssertEqual(info(anchor, on: "2026-09-02")?.date, date("2026-09-30"))
        XCTAssertEqual(info(anchor, on: "2027-02-02")?.date, date("2027-02-28"))
    }

    func test_aDayThatDoesNotExistClampsRatherThanRollingForward() {
        // Paid on the 31st: February has to resolve to the 28th, not March 3rd.
        let anchor = PayAnchor(kind: .dayOfMonth, frequency: .monthly,
                               days: [.day(31)], shiftRule: .exact)

        XCTAssertEqual(info(anchor, on: "2027-02-02")?.date, date("2027-02-28"))
    }

    func test_dayOfMonthAlsoHonoursTheShiftRule() {
        // Feb 28 2027 is a Sunday, so a "pay early" employer pays the Friday.
        let anchor = PayAnchor(kind: .dayOfMonth, frequency: .monthly,
                               days: [.last], shiftRule: .before)

        let result = info(anchor, on: "2027-02-02")

        XCTAssertEqual(result?.date, date("2027-02-26"))
        XCTAssertEqual(result?.shifted, true)
    }

    // MARK: - Holidays

    func test_aHolidayOnASaturdayClosesBanksOnTheFriday() {
        // July 4 2026 falls on a Saturday, observed Friday July 3.
        XCTAssertTrue(PaydayCalculator.isNonBanking(date("2026-07-03"), calendar: calendar))
    }

    func test_theUsualFederalHolidaysAreNonBanking() {
        for day in ["2026-01-01", "2026-01-19", "2026-05-25", "2026-06-19",
                    "2026-09-07", "2026-11-11", "2026-11-26", "2026-12-25"] {
            XCTAssertTrue(PaydayCalculator.isNonBanking(date(day), calendar: calendar),
                          "\(day) should be non-banking")
        }
    }

    func test_anOrdinaryWeekdayIsBanking() {
        XCTAssertFalse(PaydayCalculator.isNonBanking(date("2026-08-12"), calendar: calendar))
    }

    func test_aPaydayLandingOnAHolidayMovesOffIt() {
        // Nov 26 2026 is Thanksgiving, a Thursday, so the walk back has to clear
        // the holiday itself rather than only weekends.
        let anchor = PayAnchor(kind: .dayOfMonth, frequency: .monthly,
                               days: [.day(26)], shiftRule: .before)

        XCTAssertEqual(info(anchor, on: "2026-11-02")?.date, date("2026-11-25"))
    }

    // MARK: - Variable pay

    func test_variesProducesAnApproximateResult() {
        let anchor = PayAnchor(kind: .varies, frequency: .biweekly,
                               lastPaid: date("2026-08-03"))

        let result = info(anchor, on: "2026-08-11")

        XCTAssertEqual(result?.approximate, true)
        XCTAssertEqual(result?.date, date("2026-08-17"))
        XCTAssertEqual(result?.daysAway, 6)
        // Approximate schedules are never shifted: we do not know the real day,
        // so pretending to adjust it would be false precision.
        XCTAssertEqual(result?.shifted, false)
    }

    func test_variesNeverCountsDownPastZero() {
        let anchor = PayAnchor(kind: .varies, frequency: .biweekly,
                               lastPaid: date("2026-07-01"))

        let result = info(anchor, on: "2026-08-11")

        XCTAssertEqual(result?.daysAway, 0)
    }

    // MARK: - Absent and incomplete anchors

    func test_noAnchorIsTheEmptyStateRatherThanAnError() {
        XCTAssertNil(PaydayCalculator.info(for: nil, net: 100))
    }

    func test_anIncompleteAnchorProducesNothing() {
        let noDate = PayAnchor(kind: .interval, frequency: .biweekly, lastPaid: nil)
        let noDays = PayAnchor(kind: .dayOfMonth, frequency: .semiMonthly, days: [])

        XCTAssertNil(info(noDate, on: "2026-08-11"))
        XCTAssertNil(info(noDays, on: "2026-08-11"))
    }

    // MARK: - Presentation

    func test_countdownTextReadsAsASentence() {
        // VoiceOver speaks these, so "3 d" would be wrong even though it fits.
        let anchor = PayAnchor(kind: .interval, frequency: .biweekly,
                               lastPaid: date("2026-08-01"), shiftRule: .exact)

        XCTAssertEqual(PaydayCalculator.countdownText(info(anchor, on: "2026-08-14")), "Tomorrow")
        XCTAssertEqual(PaydayCalculator.countdownText(info(anchor, on: "2026-08-13")), "In 2 days")
        XCTAssertEqual(PaydayCalculator.countdownText(info(anchor, on: "2026-08-11")), "In 4 days")
        XCTAssertEqual(PaydayCalculator.countdownText(nil), "No payday set")
    }

    func test_ringProgressFillsAsPaydayApproaches() {
        let anchor = PayAnchor(kind: .interval, frequency: .biweekly,
                               lastPaid: date("2026-08-01"), shiftRule: .exact)

        let far = PaydayCalculator.periodProgress(info(anchor, on: "2026-08-03"), frequency: .biweekly)
        let near = PaydayCalculator.periodProgress(info(anchor, on: "2026-08-14"), frequency: .biweekly)

        XCTAssertLessThan(far, near)
        XCTAssertLessThanOrEqual(near, 1)
        // Never fully empty: a zero-length arc reads as a broken control.
        XCTAssertGreaterThanOrEqual(far, 0.04)
    }

    func test_notificationBodyStatesTheAmount() {
        let anchor = PayAnchor(kind: .interval, frequency: .biweekly,
                               lastPaid: date("2026-08-01"), shiftRule: .exact)
        let result = info(anchor, on: "2026-08-15")!

        let body = PaydayNotificationScheduler.body(for: result)

        XCTAssertTrue(body.contains("2,412.68"), "expected the figure in the body, got \(body)")
    }

    func test_approximateNotificationSaysSo() {
        let anchor = PayAnchor(kind: .varies, frequency: .biweekly, lastPaid: date("2026-08-03"))
        let result = info(anchor, on: "2026-08-17")!

        XCTAssertTrue(PaydayNotificationScheduler.body(for: result).contains("about"))
    }

    // MARK: - Anchor shape

    func test_cadenceDecidesWhichCaptureUiIsNeeded() {
        XCTAssertEqual(PayAnchor.shape(for: .biweekly), .interval)
        XCTAssertEqual(PayAnchor.shape(for: .weekly), .interval)
        XCTAssertEqual(PayAnchor.shape(for: .semiMonthly), .dayOfMonth)
        XCTAssertEqual(PayAnchor.shape(for: .monthly), .dayOfMonth)
    }

    func test_draftAnchorsStartOnTheCommonArrangement() {
        XCTAssertEqual(PayAnchor.draft(for: .semiMonthly).days, [.day(15), .last])
        XCTAssertEqual(PayAnchor.draft(for: .monthly).days, [.last])
        XCTAssertEqual(PayAnchor.draft(for: .biweekly).shiftRule, .before)
    }

    func test_anchorSurvivesARoundTripThroughTheAppGroup() {
        // The widget decodes exactly this payload, so a broken round trip is a
        // blank widget rather than a visible failure.
        let original = PayAnchor(kind: .dayOfMonth, frequency: .semiMonthly,
                                 days: [.day(15), .last], shiftRule: .after)

        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(PayAnchor.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}

/// Zero is the stored default for `netPerPeriod`, not a calculated result, and
/// it is the state of the entire install base on upgrade: the Calculator banner
/// asks for a payday without requiring a calculation first. Rendering it would
/// put "$0" on the Lock Screen for exactly the users the loop exists to win back.
final class PaydayNoNetTests: XCTestCase {

    private func anchor() -> PayAnchor {
        PayAnchor(kind: .interval,
                  frequency: .biweekly,
                  lastPaid: Date(timeIntervalSince1970: 1_770_000_000),
                  shiftRule: .before)
    }

    func test_zeroNetIsNotTreatedAsAFigure() {
        let info = PaydayCalculator.info(for: anchor(), net: 0)
        XCTAssertNotNil(info, "the countdown still works without an amount")
        XCTAssertFalse(info?.hasNet ?? true)
    }

    func test_aRealFigureIsTreatedAsOne() {
        let info = PaydayCalculator.info(for: anchor(), net: 2_412.55)
        XCTAssertTrue(info?.hasNet ?? false)
    }

    func test_theNotificationNeverAnnouncesZero() {
        guard let info = PaydayCalculator.info(for: anchor(), net: 0) else {
            return XCTFail("expected a countdown without an amount")
        }
        let body = PaydayNotificationScheduler.body(for: info)
        XCTAssertFalse(body.contains("$0"), "a Lock Screen alert must not read $0")
        XCTAssertFalse(body.contains("0.00"))
        XCTAssertTrue(body.contains("Payday"))
    }

    func test_theNotificationStillStatesARealAmount() {
        guard let info = PaydayCalculator.info(for: anchor(), net: 2_412.55) else {
            return XCTFail("expected a countdown")
        }
        XCTAssertTrue(PaydayNotificationScheduler.body(for: info).contains("2,412"))
    }
}
