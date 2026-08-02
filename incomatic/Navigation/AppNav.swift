//
//  AppNav.swift
//  incomatic
//
//  Created by Ben Makusha on 07/21/2026
//
//  Persistent shell chrome (Incomatic v2.0 handoff): floating bottom pill-bar
//  switcher + serif page title with optional hairline section tabs. Replaces
//  the wordmark top bar / TabView as the primary navigation surface.
//

import SwiftUI

/// The three top-level destinations in the persistent shell.
enum MainTab: Int, CaseIterable {
    case calculator, insights, history
    var label: String {
        switch self {
        case .calculator: return "Calculator"
        case .insights:   return "Insights"
        case .history:    return "History"
        }
    }
    var icon: String {
        switch self {
        case .calculator: return "doc.text"
        case .insights:   return "chart.bar"
        case .history:    return "clock.arrow.circlepath"
        }
    }
}

/// Floating bottom pill switcher: sage-tinted track, white active pill.
/// `compact` collapses the full switcher down to a small tappable handle
/// pinned to the left edge while scrolling down a long form — mirroring the
/// native tab bar's onScrollDown minimize behavior. Tapping the handle
/// (`onExpandTap`) brings the full pill back into view.
struct AppPillNav: View {
    @Binding var tab: MainTab
    var compact: Bool = false
    var onExpandTap: () -> Void = {}

    var body: some View {
        Group {
            if compact {
                collapsedHandle
            } else {
                fullPill
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: compact)
    }

    private var collapsedHandle: some View {
        Button(action: onExpandTap) {
            Image(systemName: tab.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.incSageDeep)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.incSurface))
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 20)
        .padding(.bottom, 32)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private var fullPill: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { t in
                let active = t == tab
                Button { tab = t } label: {
                    Text(t.label)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(active ? .incSageDeep : .incTextDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(active ? Color.incSurface : Color.clear)
                                .shadow(color: active ? Color.black.opacity(0.06) : .clear,
                                        radius: 3, x: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSageBg))
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }
}

/// Serif page title + optional hairline section tabs (the "Quiet Ledger" chrome).
/// `payFrequency`/`projectedPerPeriod` add a right-aligned live per-paycheck
/// figure beside the title — used by the Calculator tab so the number stays
/// visible while the header is pinned above the scroll content, instead of
/// living only in a floating bottom CTA.
struct AppSectionHeader: View {
    let title: String
    var section: Binding<CalculatorSection>? = nil
    var payFrequency: PayFrequency? = nil
    var projectedPerPeriod: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text(title)
                    .font(.system(size: 34, weight: .medium, design: .serif))
                    .foregroundColor(.incText).kerning(-1)
                if let payFrequency {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("PER \(payFrequency.displayName.uppercased())")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.incTextMute)
                            .kerning(0.5)
                        Text(projectedPerPeriod.map(formatCurrency) ?? "—")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundColor(.incSageDeep)
                    }
                }
            }
            if let section {
                HStack(spacing: 22) {
                    ForEach(CalculatorSection.allCases, id: \.self) { s in
                        let active = s == section.wrappedValue
                        Button { section.wrappedValue = s } label: {
                            VStack(spacing: 10) {
                                Text(s.displayName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(active ? .incText : .incTextMute)
                                Rectangle().fill(active ? Color.incSage : Color.clear).frame(height: 2)
                            }.fixedSize()
                        }.buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 18)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.incHairline).frame(height: 1) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12).padding(.horizontal, 26).padding(.bottom, 20)
    }
}
