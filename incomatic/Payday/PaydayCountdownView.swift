//
//
//  PaydayCountdownView.swift
//  incomatic
//
//  Created by Ben Makusha on 08/14/2026
//
//  The in-app landing surface, at the TOP OF INSIGHTS rather than in a fourth
//  tab. One component that changes size with proximity:
//
//    far   (> 3 days)  one quiet line, no card
//    near  (<= 3 days) a card with the ring, date and net
//    today             a full sage hero, the payoff for the notification tap
//
//  A fourth tab would spend 25% of the nav permanently on something that is
//  interesting 26 days a year. This spends nothing on the other 339.
//

import SwiftUI

enum CountdownPhase {
    case empty, far, near, today

    static func of(_ info: PaydayInfo?) -> CountdownPhase {
        guard let info else { return .empty }
        if info.justPaid { return .today }
        return info.daysAway <= 3 ? .near : .far
    }
}

// MARK: - Far

private struct CountdownLine: View {
    let info: PaydayInfo
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 9) {
                Circle()
                    .fill(Color.incSageSoft)
                    .frame(width: 7, height: 7)
                (
                    Text("Next payday ")
                        .foregroundColor(.incTextDim)
                    + Text(PaydayFormat.date(info.date, weekday: false))
                        .foregroundColor(.incText)
                        .fontWeight(.bold)
                    + Text(" · \(PaydayCalculator.countdownText(info).lowercased())")
                        .foregroundColor(.incTextDim)
                )
                .font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .padding(.bottom, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Next payday \(PaydayFormat.date(info.date)), \(PaydayCalculator.countdownText(info).lowercased())")
    }
}

// MARK: - Near

struct CountdownCard: View {
    let info: PaydayInfo
    var frequency: PayFrequency = .biweekly
    var onEdit: (() -> Void)?
    var onOpen: (() -> Void)?

    // The horizontal ring-plus-text layout cannot hold at accessibility sizes,
    // so it reflows to stacked rather than truncating the date.
    @Environment(\.dynamicTypeSize) private var typeSize
    private var stacked: Bool { typeSize >= .accessibility1 }

    var body: some View {
        Button { onOpen?() } label: {
            layout
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.incSageBg)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var layout: some View {
        if stacked {
            VStack(alignment: .leading, spacing: 14) {
                ring
                details
            }
        } else {
            HStack(spacing: 16) {
                ring
                details
                Spacer(minLength: 0)
                editButton
            }
        }
    }

    private var ring: some View {
        PaydayRing(size: 68,
                   stroke: 6,
                   progress: PaydayCalculator.periodProgress(info, frequency: frequency)) {
            VStack(spacing: 0) {
                // Fraunces in the design; the app uses the system serif as its
                // stand-in everywhere else, and Fraunces is not bundled.
                Text("\(info.daysAway)")
                    .font(.system(size: 21, weight: .medium, design: .serif))
                    .foregroundColor(.incSageDeep)
                Text(info.daysAway == 1 ? "DAY" : "DAYS")
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(0.6)
                    .foregroundColor(.incSage)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(info.approximate ? "PAYDAY, ABOUT" : "PAYDAY")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.incSage)
            Text(PaydayFormat.date(info.date))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.incText)
            Text(subtitle)
                .font(.system(size: 12.5))
                .foregroundColor(.incTextDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var editButton: some View {
        Button { onEdit?() } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.incSage)
                .rotationEffect(.degrees(90))
                .padding(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit your payday")
    }

    private var subtitle: String {
        // Without a calculated figure the line still has to say something, and
        // the useful something is what to do about it.
        var text = info.hasNet ? "\(formatCurrency(info.net)) expected"
                               : "Run a calculation to see the amount"
        if info.shifted, let from = info.shiftedFrom {
            // Naming the original day is what makes the shift rule visibly
            // work rather than looking like a bug in the date.
            text += " · moved up from \(PaydayFormat.weekday(from))"
        }
        return text
    }

    private var accessibilityText: String {
        var text = "Payday \(PaydayFormat.date(info.date)). \(PaydayCalculator.countdownText(info))."
        if info.hasNet { text += " \(formatCurrency(info.net)) expected." }
        return text
    }
}

// MARK: - Today

/// What the notification tap lands on. Legible in under a second: the amount,
/// the fact that it is today, and one thing worth doing next.
private struct CountdownHero: View {
    let info: PaydayInfo
    var onEdit: (() -> Void)?
    var onBreakdown: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAYDAY · \(PaydayFormat.date(info.date, weekday: false).uppercased())")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.9)
                .foregroundColor(.white.opacity(0.75))
            Text(info.hasNet ? formatCurrency(info.net) : "Payday today")
                .font(.system(size: 46, weight: .medium, design: .serif))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 8)
            Text(info.hasNet
                 ? "Landing today. This is your take-home after tax, benefits and 401(k)."
                 : "Run a calculation and the amount lands here next time.")
                .font(.system(size: 13.5))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            HStack(spacing: 8) {
                heroButton("See the breakdown") { onBreakdown?() }
                heroButton("Amount was different") { onEdit?() }
            }
            .padding(.top, 18)
        }
        .padding(EdgeInsets(top: 24, leading: 22, bottom: 22, trailing: 22))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.incSage.overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 190, height: 190)
                    .offset(x: 50, y: -70)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(info.hasNet
                            ? "Payday today. \(formatCurrency(info.net)) landing."
                            : "Payday today.")
    }

    private func heroButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty

private struct CountdownEmpty: View {
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.incSageBg)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "calendar")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(.incSage)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("Add your payday")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundColor(.incText)
                Text("One tap, and this becomes a countdown.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.incTextDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Text("Add")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(Color.incSage)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.incSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.incHairlineStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }
}

// MARK: - Entry point

/// The single view Insights renders. Phase decides the size.
struct PaydayCountdown: View {
    let anchor: PayAnchor?
    var net: Double
    var frequency: PayFrequency = .biweekly
    var now: Date = Date()
    var onEdit: (() -> Void)?
    var onAdd: (() -> Void)?
    var onOpen: (() -> Void)?
    var onBreakdown: (() -> Void)?

    private var info: PaydayInfo? {
        PaydayCalculator.info(for: anchor, net: net, now: now)
    }

    var body: some View {
        switch CountdownPhase.of(info) {
        case .empty:
            CountdownEmpty(onAdd: { onAdd?() })
        case .today:
            if let info { CountdownHero(info: info, onEdit: onEdit, onBreakdown: onBreakdown) }
        case .near:
            if let info {
                CountdownCard(info: info, frequency: frequency, onEdit: onEdit, onOpen: onOpen)
            }
        case .far:
            if let info { CountdownLine(info: info, onOpen: { onOpen?() }) }
        }
    }
}
