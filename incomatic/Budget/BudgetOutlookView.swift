//
//  BudgetOutlookView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Multi-year surplus outlook — expandable rows, one per BudgetEngine.YearOutlook.
//  Mirrors YearlyOutlookView's "expand for detail" pattern from the RSU card.
//

import SwiftUI

struct BudgetOutlookView: View {
    let years: [BudgetEngine.YearOutlook]

    private var maxTotal: Double {
        max(years.map(\.total).max() ?? 1, 1)
    }

    var body: some View {
        ScrollView {
            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Yearly surplus outlook")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.incText)
                    Text("After expenses and goal funding")
                        .font(.system(size: 12))
                        .foregroundColor(.incTextDim)
                        .padding(.bottom, 14)

                    ForEach(Array(years.enumerated()), id: \.element.year) { idx, year in
                        OutlookRow(year: year, maxTotal: maxTotal, defaultOpen: idx == 0)
                            .padding(.bottom, 10)
                    }

                    Text("Base pay and expenses held flat; this year's dated windfalls aren't assumed to repeat.")
                        .font(.system(size: 11))
                        .foregroundColor(.incTextMute)
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }
}

private struct OutlookRow: View {
    let year: BudgetEngine.YearOutlook
    let maxTotal: Double
    let defaultOpen: Bool
    @State private var open: Bool

    init(year: BudgetEngine.YearOutlook, maxTotal: Double, defaultOpen: Bool) {
        self.year = year
        self.maxTotal = maxTotal
        self.defaultOpen = defaultOpen
        _open = State(initialValue: defaultOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { open.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline) {
                        Text(String(year.year))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.incText)
                        Spacer()
                        Text("\(formatWholeCurrency(year.surplus)) surplus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.incText)
                            .monospacedDigit()
                    }
                    HStack(spacing: 0) {
                        segment(year.needs, .incSageDeep)
                        segment(year.wants, .incBlush)
                        segment(year.goalFunding, .incGold)
                        segment(max(0, year.surplus), .incTextMute)
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)

            if open {
                Text("Total \(formatWholeCurrency(year.total)) · Needs \(formatWholeCurrency(year.needs)) · Wants \(formatWholeCurrency(year.wants)) · Goal funding \(formatWholeCurrency(year.goalFunding))")
                    .font(.system(size: 12))
                    .foregroundColor(.incTextDim)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSageBg))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.incSageSoft, lineWidth: 1))
    }

    private func segment(_ value: Double, _ color: Color) -> some View {
        Rectangle().fill(color).frame(width: max(0, value / maxTotal) * 260)
    }
}
