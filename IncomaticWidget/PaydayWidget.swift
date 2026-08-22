//
//
//  PaydayWidget.swift
//  IncomaticWidget
//
//  Created by Ben Makusha on 08/14/2026
//
//  The piece the component library did not cover. Drawn at the real WidgetKit
//  families:
//    systemSmall · systemMedium · accessoryCircular · accessoryRectangular
//    · accessoryInline
//
//  Privacy rule, applied structurally rather than by convention: money is a
//  property of HOME SCREEN widgets. The accessory (Lock Screen) views have no
//  code path that renders a currency figure unless `showAmount` is explicitly
//  true, which is off by default. A Lock Screen is readable by anyone holding
//  the phone; a Home Screen is only visible once it is unlocked.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline

struct PaydayEntry: TimelineEntry {
    let date: Date
    let info: PaydayInfo?
    /// When the net figure was last computed in the app. Surfaced on the medium
    /// size, because a user who changes salary and never reopens the app would
    /// otherwise see a stale number presented as current.
    let netCalculatedAt: Date?
    let frequency: PayFrequency
}

struct PaydayProvider: TimelineProvider {

    func placeholder(in context: Context) -> PaydayEntry {
        PaydayEntry(date: Date(), info: nil, netCalculatedAt: nil, frequency: .biweekly)
    }

    func getSnapshot(in context: Context, completion: @escaping (PaydayEntry) -> Void) {
        completion(entry(for: Date()))
    }

    /// One entry per day up to and including the payday itself, then a refresh.
    ///
    /// No network call: the extension reads the anchor and the last computed net
    /// from the shared app group, so it renders correctly with the phone offline
    /// and costs nothing in budget.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PaydayEntry>) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let current = entry(for: today)

        var entries: [PaydayEntry] = []
        let horizon = min(max(current.info?.daysAway ?? 0, 0), 30)
        for offset in 0...max(horizon, 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            entries.append(entry(for: day))
        }

        // Reload the morning after the payday: that is when the countdown has to
        // roll over to the next cycle, and the app may not have been opened.
        let next = calendar.date(byAdding: .day, value: horizon + 1, to: today) ?? today
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    private func entry(for date: Date) -> PaydayEntry {
        let anchor = PaydayShared.loadAnchor()
        let net = PaydayShared.loadNet()
        let frequency = anchor?.frequency ?? .biweekly
        return PaydayEntry(
            date: date,
            info: PaydayCalculator.info(for: anchor, net: net, now: date),
            netCalculatedAt: PaydayShared.loadNetCalculatedAt(),
            frequency: frequency
        )
    }
}

// MARK: - Home Screen · small

/// Days as the hero, amount as support. Days is what changes daily, and so what
/// is worth glancing at.
struct PaydaySmallView: View {
    let entry: PaydayEntry

    var body: some View {
        if let info = entry.info {
            if info.justPaid { paid(info) } else { counting(info) }
        } else {
            empty
        }
    }

    private func counting(_ info: PaydayInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                WidgetMark()
                Spacer()
                PaydayRing(size: 26,
                           stroke: 3.5,
                           progress: PaydayCalculator.periodProgress(info, frequency: entry.frequency)) {
                    EmptyView()
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(info.approximate ? "~" : "")\(info.daysAway)")
                    .font(.system(size: 40, weight: .medium, design: .serif))
                    .foregroundColor(.incText)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(info.daysAway == 1 ? "day" : "days")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.incTextDim)
            }
            Text(info.hasNet
                 ? "\(WidgetMoney.short(info.net)) on \(PaydayFormat.date(info.date, weekday: false))"
                 : "on \(PaydayFormat.date(info.date, weekday: false))")
                .font(.system(size: 11.5))
                .foregroundColor(.incTextDim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(info))
    }

    private func paid(_ info: PaydayInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAID TODAY")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.8))
            Spacer(minLength: 0)
            Text(info.hasNet ? WidgetMoney.short(info.net) : "Today")
                .font(.system(size: 26, weight: .medium, design: .serif))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Next in \(nextGap) days")
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(info.hasNet
                            ? "Paid today. \(WidgetMoney.spoken(info.net))."
                            : "Paid today.")
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetMark()
            Spacer(minLength: 0)
            Text("Set your payday")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.incText)
            Text("Tap to add it. Takes one tap.")
                .font(.system(size: 11.5))
                .foregroundColor(.incTextDim)
                .padding(.top, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Payday not set. Tap to add it.")
    }

    private var nextGap: Int {
        switch entry.frequency {
        case .weekly: return 7
        case .daily:  return 1
        default:      return 14
        }
    }

    static func spoken(_ info: PaydayInfo) -> String {
        var text = "Payday \(PaydayFormat.date(info.date)). \(PaydayCalculator.countdownText(info))."
        if info.hasNet { text += " \(WidgetMoney.spoken(info.net)) expected." }
        return text
    }
}

// MARK: - Home Screen · medium

/// Room for the sequence, which is the thing a countdown alone cannot show:
/// this paycheck and the two after it.
struct PaydayMediumView: View {
    let entry: PaydayEntry

    var body: some View {
        if let info = entry.info {
            HStack(spacing: 18) {
                left(info)
                Divider()
                right(info)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PaydaySmallView.spoken(info))
        } else {
            empty
        }
    }

    private func left(_ info: PaydayInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetMark(showLabel: true)
            Spacer(minLength: 0)
            if info.justPaid {
                Text("PAID TODAY")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.incSage)
                Text(info.hasNet ? WidgetMoney.short(info.net) : "Today")
                    .font(.system(size: 30, weight: .medium, design: .serif))
                    .foregroundColor(.incText)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.top, 3)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(info.approximate ? "~" : "")\(info.daysAway)")
                        .font(.system(size: 38, weight: .medium, design: .serif))
                        .foregroundColor(.incText)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(info.daysAway == 1 ? "day" : "days")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.incTextDim)
                }
                Text("until \(PaydayFormat.date(info.date, weekday: false))")
                    .font(.system(size: 11.5))
                    .foregroundColor(.incTextDim)
                    .lineLimit(1)
                    .padding(.top, 3)
            }
        }
        .frame(width: 130, alignment: .leading)
    }

    private func right(_ info: PaydayInfo) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("NEXT THREE")
                .font(.system(size: 9.5, weight: .heavy))
                .tracking(0.7)
                .foregroundColor(.incTextDim)
            ForEach(Array(upcoming(info).enumerated()), id: \.offset) { index, date in
                HStack {
                    Text(PaydayFormat.date(date, weekday: false))
                        .font(.system(size: 12.5, weight: index == 0 ? .bold : .medium))
                        .foregroundColor(index == 0 ? .incText : .incTextDim)
                    if info.hasNet {
                        Spacer(minLength: 4)
                        Text(WidgetMoney.short(info.net))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(index == 0 ? .incSageDeep : .incTextDim)
                            .monospacedDigit()
                    }
                }
            }
            if let stamp = entry.netCalculatedAt {
                // The honest caveat: the figure is whatever the app last worked
                // out, not a live recalculation.
                Text("Figure from \(PaydayFormat.date(stamp, weekday: false))")
                    .font(.system(size: 9))
                    .foregroundColor(.incTextMute)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Projected forward from the resolved date. Approximate for day-of-month
    /// rules, which is acceptable here: the first row is exact and the two
    /// behind it are context rather than commitments.
    private func upcoming(_ info: PaydayInfo) -> [Date] {
        let step: Int
        switch entry.frequency {
        case .weekly:      step = 7
        case .daily:       step = 1
        case .semiMonthly: step = 15
        case .monthly:     step = 30
        default:           step = 14
        }
        return (0..<3).compactMap {
            Calendar.current.date(byAdding: .day, value: $0 * step, to: info.date)
        }
    }

    private var empty: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.incSageBg)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "calendar")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.incSage)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("Add your payday")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.incText)
                Text("Incomatic will count down to it here. Tap to set it in the app.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.incTextDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Payday not set. Tap to add it in Incomatic.")
    }
}

// MARK: - Lock Screen

/// Days only. There is deliberately no amount branch in this view at all, so no
/// future edit can leak a salary onto a locked phone by flipping a flag.
struct PaydayCircularView: View {
    let entry: PaydayEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let info = entry.info {
                if info.justPaid {
                    Text("PAID").font(.system(size: 12, weight: .heavy))
                } else {
                    VStack(spacing: -1) {
                        Text("\(info.daysAway)")
                            .font(.system(size: 24, weight: .bold))
                        Text("DAYS")
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.8)
                    }
                }
            } else {
                Text("Set\nday")
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        guard let info = entry.info else { return "Payday not set" }
        return info.justPaid ? "Paid today" : PaydayCalculator.countdownText(info)
    }
}

/// Days plus the date. `showAmount` exists, defaults false, and is only settable
/// from the widget's own configuration with the warning attached to the control.
struct PaydayRectangularView: View {
    let entry: PaydayEntry
    var showAmount = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .bold))
                Text("PAYDAY")
                    .font(.system(size: 10.5, weight: .bold))
            }
            .opacity(0.7)

            if let info = entry.info {
                if info.justPaid {
                    Text("Today").font(.system(size: 19, weight: .bold))
                    Text(showAmount && info.hasNet
                         ? "\(WidgetMoney.short(info.net)) landing"
                         : "Open to see the amount")
                        .font(.system(size: 11.5))
                        .opacity(0.7)
                } else {
                    Text("\(info.approximate ? "About " : "")\(info.daysAway) \(info.daysAway == 1 ? "day" : "days")")
                        .font(.system(size: 19, weight: .bold))
                    Text(PaydayFormat.date(info.date, weekday: false)
                         + (showAmount && info.hasNet ? " · \(WidgetMoney.short(info.net))" : ""))
                        .font(.system(size: 11.5))
                        .opacity(0.7)
                }
            } else {
                Text("Not set yet").font(.system(size: 15, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.info.map { PaydayCalculator.countdownText($0) } ?? "Payday not set")
    }
}

struct PaydayInlineView: View {
    let entry: PaydayEntry
    var body: some View {
        if let info = entry.info {
            Label(info.justPaid ? "Payday today" : "Payday \(PaydayCalculator.countdownText(info).lowercased())",
                  systemImage: "calendar")
        } else {
            Label("Payday not set", systemImage: "calendar")
        }
    }
}

// MARK: - Shared bits

struct WidgetMark: View {
    var showLabel = false
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.incSage)
                .frame(width: 18, height: 18)
                .overlay(
                    Text("i")
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .italic()
                        .foregroundColor(.white)
                )
            if showLabel {
                Text("incomatic")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.incTextDim)
            }
        }
    }
}

enum WidgetMoney {
    /// Whole dollars. Cents cost three characters that a 158pt tile does not
    /// have, and nobody glances at a widget for the cents.
    static func short(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    /// VoiceOver reads the full figure, where cents cost nothing.
    static func spoken(_ amount: Double) -> String {
        formatCurrency(amount)
    }
}

// MARK: - Widget definitions

struct PaydayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "IncomaticPayday", provider: PaydayProvider()) { entry in
            PaydayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Payday")
        .description("Counts down to your next paycheck.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct PaydayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PaydayEntry

    /// Applied in exactly one place. `containerBackground` does not compose:
    /// setting it inside a subview and again out here means the outer one wins,
    /// which silently cost the just-paid state its sage fill.
    private var systemBackground: Color {
        let paid = entry.info?.justPaid ?? false
        // Only the small size inverts on payday. The medium keeps its surface,
        // because its right-hand column of upcoming dates needs the contrast.
        return (paid && family == .systemSmall) ? .incSage : .incSurface
    }

    var body: some View {
        switch family {
        case .systemSmall:
            PaydaySmallView(entry: entry)
                .containerBackground(systemBackground, for: .widget)
        case .systemMedium:
            PaydayMediumView(entry: entry)
                .containerBackground(systemBackground, for: .widget)
        case .accessoryCircular:
            PaydayCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            PaydayRectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        default:
            PaydayInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
    }
}

@main
struct IncomaticWidgetBundle: WidgetBundle {
    var body: some Widget {
        PaydayWidget()
    }
}
