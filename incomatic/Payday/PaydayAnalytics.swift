//
//  PaydayAnalytics.swift
//  incomatic
//
//  Created by Ben Makusha on 08/21/2026
//
//  The payday loop's event vocabulary, in one place.
//
//  R3 exists to move a single number: at least one session per pay period for
//  activated users. That makes `anchorSet` the load-bearing event, because it
//  is what defines "activated" — and a cohort cannot be reconstructed after the
//  fact, so it has to ship in the same release as the loop rather than in a
//  follow-up. Sessions themselves are already counted by `session_start`;
//  `opened` only adds attribution on top of that.
//
//  Emitted from the call sites rather than from inside `PaydayStore`, which is
//  a deliberate trade. Centralising it in the store would make it impossible to
//  forget, but the store is pure and unit-tested, and giving it an analytics
//  dependency means either writing real events during tests or injecting a sink
//  whose default argument would land on the same nonisolated-default-argument
//  trap the shared payday types were just fixed for.
//
//  NOTHING HERE MAY CARRY AN AMOUNT. Every value below is an enum case or a
//  bool, so a salary figure cannot be passed even by accident — the same rule
//  `QueuedEvent`'s `[String: String]` shape enforces one level up.
//

import Foundation

/// Which of the three capture placements produced an anchor.
enum PaydayAskSource: String {
    /// Full-screen ask immediately after a result. Candidate A.
    case reveal
    /// The payday step in the guided onboarding notebook. Candidate C.
    case onboarding
    /// The two-pass Calculator banner — the only placement that reaches the
    /// install base, who never see onboarding again.
    case banner
    /// Editing an anchor that already exists. Never activation.
    case insightsEdit = "insights_edit"
}

/// What brought the user back into the app.
enum PaydayOpenSource: String {
    case notification
    case widget
}

enum PaydayAnalytics {

    /// An anchor was stored. `first` separates activation from a later edit:
    /// the cohort is defined by the first anchor only, so counting edits into
    /// it would inflate the denominator of the very metric Phase 2 is gated on.
    static func anchorSet(_ anchor: PayAnchor, source: PaydayAskSource, first: Bool) {
        Analytics.shared.track(AnalyticsEventName.paydayAnchorSet, properties: [
            "source": source.rawValue,
            "kind": anchor.kind.rawValue,
            "frequency": anchor.frequency.rawValue,
            "shift_rule": anchor.shiftRule.rawValue,
            "first": String(first)
        ])
    }

    /// One of the asks was put in front of the user. Pairing this with
    /// `anchorSet` is what makes the three placements comparable rather than
    /// merely counted — a placement that shows often and converts rarely is
    /// worth removing, and that is invisible without the denominator.
    static func promptShown(_ source: PaydayAskSource, pass: Int? = nil) {
        Analytics.shared.track(AnalyticsEventName.paydayPromptShown,
                               properties: properties(source, pass))
    }

    /// An ask was closed without an anchor being set.
    static func promptDismissed(_ source: PaydayAskSource, pass: Int? = nil) {
        Analytics.shared.track(AnalyticsEventName.paydayPromptDismissed,
                               properties: properties(source, pass))
    }

    /// The app was opened from something the loop produced.
    static func opened(from source: PaydayOpenSource) {
        Analytics.shared.track(AnalyticsEventName.paydayOpen,
                               properties: ["source": source.rawValue])
    }

    /// `pass` is the banner's ladder position and is absent for every other
    /// placement, rather than defaulted to a number that would read as real.
    static func properties(_ source: PaydayAskSource, _ pass: Int?) -> [String: String] {
        var props = ["source": source.rawValue]
        if let pass { props["pass"] = String(pass) }
        return props
    }
}
