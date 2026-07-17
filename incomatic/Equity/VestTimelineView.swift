//
//  VestTimelineView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  Year-level vest distribution for one grant (§D). A 4-year monthly schedule
//  is 37 events, so rows roll up per year — "2026 · 250 sh ≈ $58,035 (4 vests)".
//  The current tax year is highlighted in sage with a text caption (the label,
//  not the color, is the accessible channel); a cliff year gets a gold marker.
//

import SwiftUI

struct VestTimelineView: View {
    let grant: RsuGrant

    private var groups: [VestMath.YearGroup] { VestMath.yearGroups(for: grant) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if groups.isEmpty {
                Text("Set shares, price, and a grant date to preview vesting.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.incTextMute)
                    .padding(.vertical, 8)
            } else {
                ForEach(groups) { group in
                    yearRow(group)
                }
            }
        }
    }

    private func yearRow(_ group: VestMath.YearGroup) -> some View {
        let isCurrent = group.year == AppConfig.taxYear
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isCurrent ? Color.incSage : (group.hasCliff ? Color.incGold : Color.incHairlineStrong))
                    .frame(width: group.hasCliff ? 12 : 8, height: group.hasCliff ? 12 : 8)
                Text(String(group.year))
                    .font(.system(size: 14, weight: isCurrent ? .bold : .semibold))
                    .foregroundColor(.incText)
                    .monospacedDigit()
                Spacer()
                Text("\(formatShares(group.shares)) sh ≈ \(formatWholeCurrency(group.value))")
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(isCurrent ? .incText : .incTextDim)
                    .monospacedDigit()
                Text("(\(group.vestCount) \(group.vestCount == 1 ? "vest" : "vests"))")
                    .font(.system(size: 11))
                    .foregroundColor(.incTextMute)
            }
            if isCurrent {
                Text("Counts toward your \(String(AppConfig.taxYear)) paycheck")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.incSage)
                    .padding(.leading, 18)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, isCurrent ? 10 : 0)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? Color.incSageBg : Color.clear)
        )
        .accessibilityElement(children: .combine)
    }
}

func formatShares(_ shares: Double) -> String {
    shares.truncatingRemainder(dividingBy: 1) == 0
        ? String(Int(shares))
        : String(format: "%.1f", shares)
}

/// Whole-dollar summaries ("$58,035") per the design's currency rules.
func formatWholeCurrency(_ amount: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
}
