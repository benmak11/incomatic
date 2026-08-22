//
//
//  PaydayShared.swift
//  incomatic
//
//  Created by Ben Makusha on 08/14/2026
//
//  Shared by the app AND the widget extension. Keep this file free of anything
//  app-only: the extension compiles it too, and a stray @AppStorage or
//  ObservableObject here becomes an extension build failure.
//
//  The shared payday types are explicitly `nonisolated`. The app target builds
//  with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor and the widget target does
//  not, so without this the same source compiles under different isolation in
//  each target: MainActor in the app, nonisolated in the extension. Saying it
//  outright makes the two agree, and it is also the truthful answer for storage
//  reads and date math that a TimelineProvider has to run off the main actor.
//

import SwiftUI

/// Storage the widget extension reads. The app writes it through PaydayStore.
nonisolated enum PaydayShared {
    /// Requires the App Group capability on BOTH targets. Until that is added in
    /// Xcode this still returns a usable UserDefaults, so the app behaves
    /// normally and only the widget sees an empty anchor.
    static let appGroupID = "group.com.makusha.incomatic"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    enum Key {
        static let anchor = "incomatic.payday.anchor"
        /// Net per paycheck as of the last calculation, so the widget can show a
        /// figure without recomputing tax.
        static let lastNet = "incomatic.payday.lastNet"
        /// When that figure was computed. Shown on the medium widget, because a
        /// user who changes salary and never reopens the app would otherwise see
        /// a stale number presented as current.
        static let lastNetAt = "incomatic.payday.lastNetAt"
        static let payFrequency = "incomatic.payday.frequency"
    }

    static func loadAnchor(from store: UserDefaults? = nil) -> PayAnchor? {
        guard let data = (store ?? defaults).data(forKey: Key.anchor) else { return nil }
        return try? JSONDecoder().decode(PayAnchor.self, from: data)
    }

    static func loadNet() -> Double {
        defaults.double(forKey: Key.lastNet)
    }

    static func loadNetCalculatedAt() -> Date? {
        let stamp = defaults.double(forKey: Key.lastNetAt)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }
}

// MARK: - Formatting

nonisolated enum PaydayFormat {
    /// "Friday, Aug 14" or "Aug 14". Written out rather than numeric because
    /// VoiceOver reads the same string.
    static func date(_ date: Date, weekday: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = weekday ? "EEEE, MMM d" : "MMM d"
        return formatter.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    /// Single-letter weekday for the date strip header.
    static func weekdayInitial(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Ring

/// Progress is the elapsed share of the pay period, so it fills as payday
/// approaches. Decorative: the accessible sentence lives on the parent, so the
/// ring is hidden from VoiceOver rather than read out as a percentage.
struct PaydayRing<Content: View>: View {
    var size: CGFloat = 68
    var stroke: CGFloat = 6
    var progress: Double
    var color: Color = .incSage
    var track: Color = .incTrack
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: stroke)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            content
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
