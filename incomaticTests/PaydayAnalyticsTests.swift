//
//  PaydayAnalyticsTests.swift
//  incomaticTests
//
//  R3's whole justification is a measurement, so the event vocabulary is
//  load-bearing in a way most view code is not: a name the backend rejects
//  produces no error the app can see, and the cohort it was meant to define
//  simply never exists.
//

import XCTest
@testable import Incomatic

@MainActor
final class PaydayAnalyticsTests: XCTestCase {

    /// The backend enforces `[a-z][a-z0-9_]{0,49}` on event names and drops
    /// anything else. Nothing client-side surfaces that rejection, so a typo
    /// would look exactly like a feature nobody used.
    func test_everyEventNameSurvivesTheBackendsValidator() {
        let pattern = try? NSRegularExpression(pattern: "^[a-z][a-z0-9_]{0,49}$")
        let names = [
            AnalyticsEventName.sessionStart,
            AnalyticsEventName.onboardingStep,
            AnalyticsEventName.onboardingCompleted,
            AnalyticsEventName.calculationCompleted,
            AnalyticsEventName.linkCodeGenerated,
            AnalyticsEventName.linkCodeRedeemed,
            AnalyticsEventName.paydayAnchorSet,
            AnalyticsEventName.paydayPromptShown,
            AnalyticsEventName.paydayPromptDismissed,
            AnalyticsEventName.paydayOpen
        ]
        for name in names {
            let range = NSRange(name.startIndex..., in: name)
            XCTAssertNotNil(
                pattern?.firstMatch(in: name, range: range),
                "\(name) would be rejected by the backend and silently dropped"
            )
        }
    }

    /// Underscored raw values are the ones that drift, because the Swift case
    /// name and the wire name stop matching.
    func test_askSourcesUseTheirWireNames() {
        XCTAssertEqual(PaydayAskSource.reveal.rawValue, "reveal")
        XCTAssertEqual(PaydayAskSource.onboarding.rawValue, "onboarding")
        XCTAssertEqual(PaydayAskSource.banner.rawValue, "banner")
        XCTAssertEqual(PaydayAskSource.insightsEdit.rawValue, "insights_edit")
    }

    func test_openSourcesUseTheirWireNames() {
        XCTAssertEqual(PaydayOpenSource.notification.rawValue, "notification")
        XCTAssertEqual(PaydayOpenSource.widget.rawValue, "widget")
    }

    /// Only the banner has a ladder position. Defaulting the others to a number
    /// would make a placement that has no passes look like it has one.
    func test_passIsOmittedForPlacementsThatDoNotHaveOne() {
        XCTAssertNil(PaydayAnalytics.properties(.reveal, nil)["pass"])
        XCTAssertEqual(PaydayAnalytics.properties(.banner, 2)["pass"], "2")
        XCTAssertEqual(PaydayAnalytics.properties(.banner, 1)["source"], "banner")
    }

    /// The one rule that outranks the metric: an event may never carry a
    /// figure. `anchorSet` takes a whole `PayAnchor`, which is the type most
    /// likely to grow an amount-shaped field later.
    func test_anchorPropertiesCarryNoAmounts() {
        let anchor = PayAnchor(kind: .interval,
                               frequency: .biweekly,
                               lastPaid: Date(),
                               shiftRule: .before)
        let props: [String: String] = [
            "kind": anchor.kind.rawValue,
            "frequency": anchor.frequency.rawValue,
            "shift_rule": anchor.shiftRule.rawValue,
            "first": String(true)
        ]
        for (key, value) in props {
            XCTAssertNil(Double(value), "\(key) sends a number, which is how a salary leaks")
        }
    }
}
