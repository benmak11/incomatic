//
//
//  PaydayStore.swift
//  incomatic
//
//  Created by Ben Makusha on 08/14/2026
//
//  Persistence for the payday loop. Everything the widget extension needs to
//  render without a network call lives in the shared app group; everything only
//  the app cares about (banner state, priming) stays in standard defaults.
//

import Combine
import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Owns the anchor and the small pieces of loop state around it.
@MainActor
final class PaydayStore: ObservableObject {

    @Published private(set) var anchor: PayAnchor?
    /// Net per paycheck from the most recent calculation. Mirrored into the app
    /// group for the widget.
    @Published private(set) var netPerPeriod: Double = 0

    /// Whether the user accepted the priming ask. Not the same as the system
    /// permission, which can be revoked in Settings without us being told.
    @AppStorage("incomatic.payday.primingAnswered") var primingAnswered = false

    // Existing-user banner ladder. Pass 1 is a quiet line; pass 2 shows the
    // widget preview once, and only if pass 1 was dismissed without action and
    // the user has since run a calculation. After that it never asks again.
    @AppStorage("incomatic.payday.bannerPass1Dismissed") var bannerPass1Dismissed = false
    @AppStorage("incomatic.payday.bannerPass2Shown") var bannerPass2Shown = false
    @AppStorage("incomatic.payday.bannerRetired") var bannerRetired = false

    /// Whether the anchor has been asked for at the results reveal (candidate A)
    /// or during onboarding (candidate C). Either counts: the point is that the
    /// full-screen ask happens once per install and never nags.
    @AppStorage("incomatic.payday.revealAsked") var revealAsked = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = PaydayShared.defaults) {
        self.defaults = defaults
        // Read from the SAME store we write to. These are the same object in
        // production, but reading the global suite here made the store
        // untestable and would silently ignore any injected defaults.
        self.anchor = PaydayShared.loadAnchor(from: defaults)
        self.netPerPeriod = defaults.double(forKey: PaydayShared.Key.lastNet)
    }

    // MARK: - Anchor

    func save(_ anchor: PayAnchor) {
        self.anchor = anchor
        if let data = try? JSONEncoder().encode(anchor) {
            defaults.set(data, forKey: PaydayShared.Key.anchor)
        }
        defaults.set(anchor.frequency.rawValue, forKey: PaydayShared.Key.payFrequency)
        refreshDependents()
    }

    func clearAnchor() {
        anchor = nil
        defaults.removeObject(forKey: PaydayShared.Key.anchor)
        refreshDependents()
    }

    /// Called after every successful calculation so the widget and the
    /// notification body carry a real figure rather than a placeholder.
    func recordNet(_ net: Double, frequency: PayFrequency) {
        guard net > 0 else { return }
        netPerPeriod = net
        defaults.set(net, forKey: PaydayShared.Key.lastNet)
        defaults.set(Date().timeIntervalSince1970, forKey: PaydayShared.Key.lastNetAt)
        defaults.set(frequency.rawValue, forKey: PaydayShared.Key.payFrequency)

        // Keep the anchor's cadence in step with the calculator. Changing pay
        // frequency changes the schedule shape, so an interval anchor left on a
        // semi-monthly cadence would count down to the wrong day.
        if var current = anchor, current.frequency != frequency {
            let neededShape = PayAnchor.shape(for: frequency)
            if current.kind != .varies && current.kind != neededShape {
                // The shape changed, so the stored detail no longer applies and
                // asking again beats silently guessing.
                clearAnchor()
            } else {
                current.frequency = frequency
                save(current)
                return
            }
        }
        refreshDependents()
    }

    var info: PaydayInfo? {
        PaydayCalculator.info(for: anchor, net: netPerPeriod)
    }

    // MARK: - The reveal ask

    /// True when the results reveal should stop and ask for a payday.
    var shouldAskOnReveal: Bool { anchor == nil && !revealAsked }

    /// The user declined the ask at the reveal.
    ///
    /// Also consumes the banner's first pass. Pass 1 is a quieter version of the
    /// same question, so showing it minutes after a full-screen decline reads as
    /// nagging; the ladder resumes at pass 2, which the design already gates on
    /// "dismissed without action and has since calculated".
    func declineReveal() {
        revealAsked = true
        bannerPass1Dismissed = true
    }

    // MARK: - Banner ladder

    /// Which existing-user banner to show, if any. `nil` means show nothing.
    func bannerPass(hasCalculated: Bool) -> Int? {
        guard anchor == nil, !bannerRetired else { return nil }
        if !bannerPass1Dismissed { return 1 }
        if hasCalculated && !bannerPass2Shown { return 2 }
        return nil
    }

    func dismissBanner(pass: Int) {
        if pass == 1 {
            bannerPass1Dismissed = true
        } else {
            bannerPass2Shown = true
            bannerRetired = true
        }
    }

    // MARK: - Fan-out

    /// One place to poke everything that derives from the anchor, so a caller
    /// can never save an anchor and forget to reschedule the notification.
    private func refreshDependents() {
        PaydayNotificationScheduler.reschedule(anchor: anchor, net: netPerPeriod)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
