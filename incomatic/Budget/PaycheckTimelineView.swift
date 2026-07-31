//
//  PaycheckTimelineView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Horizontal-scroll paycheck-by-paycheck timeline — one card per
//  BudgetEngine.Paycheck. Windfall periods (a Windfall landed that period)
//  get a wider card + colored border + a badge, matching the design mock's
//  "some paychecks run tighter, some run bigger" story.
//

import SwiftUI

struct PaycheckTimelineView: View {
    let paychecks: [BudgetEngine.Paycheck]
    /// Index of the paycheck closest to today, for the "TODAY" badge.
    let todayIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Some paychecks run tighter than others. Bigger windfalls widen the bar, tighter weeks shrink it.")
                .font(.system(size: 13))
                .foregroundColor(.incTextDim)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(paychecks) { paycheck in
                        PaycheckCard(paycheck: paycheck, isToday: paycheck.index == todayIndex)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 100)
    }
}

private struct PaycheckCard: View {
    let paycheck: BudgetEngine.Paycheck
    let isToday: Bool

    private var hasWindfall: Bool { paycheck.windfallNet > 0 }
    private var maxBar: Double { max(paycheck.needs + paycheck.wants + paycheck.savings, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasWindfall {
                Text("+ \(paycheck.windfallLabel ?? "Windfall")")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.incGold))
            }

            Text(paycheck.payDate.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.incTextMute)

            Text(formatWholeCurrency(paycheck.takeHome))
                .font(.system(size: hasWindfall ? 22 : 18, weight: .bold))
                .foregroundColor(.incText)
                .monospacedDigit()

            HStack(spacing: 0) {
                bar(paycheck.needs, .incSageDeep)
                bar(paycheck.wants, .incBlush)
                bar(paycheck.savings, .incGold)
            }
            .frame(height: hasWindfall ? 12 : 7)
            .clipShape(Capsule())

            Text("Needs \(formatWholeCurrency(paycheck.needs)) · Wants \(formatWholeCurrency(paycheck.wants)) · Goals \(formatWholeCurrency(paycheck.savings))")
                .font(.system(size: 10.5))
                .foregroundColor(.incTextDim)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle().fill(Color.incHairline).frame(height: 1)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LEFTOVER").font(.system(size: 9.5, weight: .bold)).foregroundColor(.incTextMute)
                    Text(formatWholeCurrency(paycheck.leftover))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(paycheck.leftover < 100 ? .incBlush : .incSageDeep)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("BALANCE").font(.system(size: 9.5, weight: .bold)).foregroundColor(.incTextMute)
                    Text(formatWholeCurrency(paycheck.runningBalance))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.incText)
                }
            }
        }
        .padding(16)
        .frame(width: hasWindfall ? 208 : 172, alignment: .leading)
        .background(Color.incSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(hasWindfall ? Color.incGold : Color.incCardBorder, lineWidth: hasWindfall ? 1.5 : 1)
        )
        .overlay(alignment: .topLeading) {
            if isToday {
                Text("TODAY")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.incBg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.incText))
                    .offset(x: 14, y: -9)
            }
        }
    }

    private func bar(_ value: Double, _ color: Color) -> some View {
        Rectangle().fill(color).frame(width: max(0, value / maxBar) * 140)
    }
}
