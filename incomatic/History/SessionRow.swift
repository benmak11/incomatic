//
//  SessionRow.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Single row in the History list — mini donut, state name + freq, savedAt /
//  take-home amount / take-home % subline, and a chevron.
//

import SwiftUI

struct SessionRow: View {
    let summary: SavedCalculationSummary
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                MiniDonut(
                    takeHome: summary.takeHomePerPeriod ?? 0,
                    taxes:    summary.taxesPerPeriod    ?? 0,
                    benefits: summary.benefitsPerPeriod ?? 0
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.displayTitle)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(.incText)
                        .kerning(-0.2)
                    Text(summary.displaySubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.incTextMute)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(summary.savedAtCompact.uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.incTextMute)
                        .kerning(0.6)
                    Text(Self.compactMoney(summary.takeHomePerPeriod ?? 0))
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(.incText)
                        .monospacedDigit()
                        .kerning(-0.3)
                    Text(percentLabel)
                        .font(.system(size: 11.5))
                        .foregroundColor(.incTextDim)
                        .monospacedDigit()
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.incTextMute)
                    .padding(.leading, 2)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.incHairline).frame(height: 1).padding(.leading, 58)
            }
        }
    }

    private var percentLabel: String {
        let pct = summary.takeHomePct ?? 0
        let gross = summary.grossPerPeriod ?? 0
        return "\(Int(pct.rounded()))% of \(Self.compactMoney(gross))"
    }

    private static func compactMoney(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 0
        fmt.currencyCode = "USD"
        return fmt.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}
