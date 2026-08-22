//
//
//  PaydayStoreTests.swift
//  incomaticTests
//
//  Created by Ben Makusha on 08/14/2026
//
//  The loop asks for a payday from three places: onboarding, the results reveal,
//  and the Calculator banner. Getting the ladder wrong means asking the same
//  person three times in one session, so the gating is pinned here.
//

import XCTest
@testable import Incomatic

@MainActor
final class PaydayStoreTests: XCTestCase {

    private let keys = [
        "incomatic.payday.anchor",
        "incomatic.payday.lastNet",
        "incomatic.payday.lastNetAt",
        "incomatic.payday.frequency",
        "incomatic.payday.revealAsked",
        "incomatic.payday.primingAnswered",
        "incomatic.payday.bannerPass1Dismissed",
        "incomatic.payday.bannerPass2Shown",
        "incomatic.payday.bannerRetired",
    ]

    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        // A named suite for the anchor, and the standard domain for the
        // @AppStorage flags, which always resolve there.
        suite = UserDefaults(suiteName: "payday.tests")!
        clear()
    }

    override func tearDown() {
        clear()
        suite = nil
        super.tearDown()
    }

    private func clear() {
        for key in keys {
            suite.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func makeStore() -> PaydayStore {
        PaydayStore(defaults: suite)
    }

    private var anchor: PayAnchor {
        PayAnchor(kind: .interval, frequency: .biweekly, lastPaid: Date(), shiftRule: .before)
    }

    // MARK: - The reveal ask

    func test_aFreshInstallIsAskedAtTheReveal() {
        XCTAssertTrue(makeStore().shouldAskOnReveal)
    }

    func test_theRevealNeverAsksTwice() {
        let store = makeStore()
        store.declineReveal()

        XCTAssertFalse(store.shouldAskOnReveal)
    }

    func test_someoneWithAPaydayIsNeverAskedAtTheReveal() {
        let store = makeStore()
        store.save(anchor)

        XCTAssertFalse(store.shouldAskOnReveal)
    }

    // MARK: - The banner ladder

    func test_theBannerOpensWithTheQuietLine() {
        XCTAssertEqual(makeStore().bannerPass(hasCalculated: false), 1)
    }

    func test_pass2NeedsACalculationBehindIt() {
        let store = makeStore()
        store.dismissBanner(pass: 1)

        // Selling a countdown to someone who has never seen a figure is selling
        // a countdown to a number they do not have.
        XCTAssertNil(store.bannerPass(hasCalculated: false))
        XCTAssertEqual(store.bannerPass(hasCalculated: true), 2)
    }

    func test_theBannerRetiresAfterPass2() {
        let store = makeStore()
        store.dismissBanner(pass: 1)
        store.dismissBanner(pass: 2)

        XCTAssertNil(store.bannerPass(hasCalculated: true))
    }

    func test_decliningTheRevealSkipsTheQuietLine() {
        // Pass 1 is the same question in a smaller box, so showing it minutes
        // after a full-screen decline is nagging.
        let store = makeStore()
        store.declineReveal()

        XCTAssertNotEqual(store.bannerPass(hasCalculated: true), 1)
        XCTAssertEqual(store.bannerPass(hasCalculated: true), 2)
    }

    func test_settingAPaydaySilencesTheBannerEntirely() {
        let store = makeStore()
        store.save(anchor)

        XCTAssertNil(store.bannerPass(hasCalculated: true))
    }

    // MARK: - Net and cadence

    func test_theNetIsSharedSoTheWidgetCanRenderIt() {
        let store = makeStore()
        store.recordNet(2412.68, frequency: .biweekly)

        XCTAssertEqual(suite.double(forKey: "incomatic.payday.lastNet"), 2412.68)
        XCTAssertGreaterThan(suite.double(forKey: "incomatic.payday.lastNetAt"), 0)
    }

    func test_aZeroNetIsIgnoredRatherThanStored() {
        // A failed or empty calculation must not blank the widget's figure.
        let store = makeStore()
        store.recordNet(2412.68, frequency: .biweekly)
        store.recordNet(0, frequency: .biweekly)

        XCTAssertEqual(store.netPerPeriod, 2412.68)
    }

    func test_changingCadenceWithinTheSameShapeKeepsTheAnchor() {
        let store = makeStore()
        store.save(PayAnchor(kind: .interval, frequency: .biweekly,
                             lastPaid: Date(), shiftRule: .before))

        store.recordNet(1000, frequency: .weekly)

        XCTAssertNotNil(store.anchor)
        XCTAssertEqual(store.anchor?.frequency, .weekly)
    }

    func test_changingToADifferentScheduleShapeClearsTheAnchor() {
        // Bi-weekly counts forward from a date; semi-monthly is a day-of-month
        // rule. The stored detail cannot be reinterpreted, so asking again beats
        // counting down to a day the user never chose.
        let store = makeStore()
        store.save(PayAnchor(kind: .interval, frequency: .biweekly,
                             lastPaid: Date(), shiftRule: .before))

        store.recordNet(1000, frequency: .semiMonthly)

        XCTAssertNil(store.anchor)
    }

    func test_theAnchorSurvivesANewStoreInstance() {
        makeStore().save(anchor)

        XCTAssertNotNil(makeStore().anchor)
    }
}
