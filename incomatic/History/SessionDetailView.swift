//
//  SessionDetailView.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Detail of a single saved calculation. Custom nav header (back + trash), big
//  donut, then the same itemized breakdown the Insights tab renders.
//

import SwiftUI

struct SessionDetailView: View {
    let summary: SavedCalculationSummary
    @State private var detail: SavedCalculationDetail?
    @State private var loadError: String?
    let onBack: () -> Void
    let onDelete: () async -> Void

    private let historyService = CalculationHistoryService()
    let viewModel: HistoryViewModel

    private let takeHomeColor = Color.incSage
    private let taxesColor    = Color.incBlush
    private let benefitsColor = Color.incGold

    var body: some View {
        ZStack {
            Color.incBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    navHeader
                    pageHeader
                    contentBody
                }
                .padding(.bottom, 100)
            }
        }
        .task { await loadDetail() }
    }

    private var navHeader: some View {
        HStack(alignment: .center) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                    Text("History")
                        .font(.system(size: 15.5, weight: .semibold))
                }
                .foregroundColor(.incSage)
            }
            Spacer()
            Button {
                Task { await onDelete() }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.incTextDim)
                    .padding(6)
            }
            .accessibilityLabel("Delete from history")
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
        .padding(.bottom, 6)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SAVED \(summary.savedAtCompact.uppercased()) · \(summary.displaySubtitle.uppercased())")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.incSage)
                .kerning(0.8)
                .lineLimit(1)
            Text(summary.displayTitle)
                .font(.system(size: 32, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .kerning(-1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var contentBody: some View {
        if let loadError {
            VStack(spacing: 10) {
                Text("Couldn't load this session")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.incText)
                Text(loadError)
                    .font(.system(size: 13))
                    .foregroundColor(.incTextDim)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await loadDetail() } }
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.top, 32)
        } else if detail == nil {
            VStack {
                ProgressView().tint(.incSage)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            VStack(spacing: 12) {
                donutCard
                if let detail {
                    EarningsBreakdownView(
                        result: HistoryDetailMapper.viewFriendly(from: detail),
                        onAdjust: onBack
                    )
                    .frame(maxWidth: .infinity)
                }
                Button {
                    Task { await onDelete() }
                } label: {
                    Text("Delete from history")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.incRed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.incRed.opacity(0.18), lineWidth: 1.5)
                        )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
        }
    }

    private var donutCard: some View {
        VStack(spacing: 14) {
            ZStack {
                DonutChart(
                    wedges: [
                        .init(value: summary.takeHomePerPeriod ?? 0, color: takeHomeColor),
                        .init(value: summary.taxesPerPeriod ?? 0,    color: taxesColor),
                        .init(value: summary.benefitsPerPeriod ?? 0, color: benefitsColor),
                    ],
                    centerLabel: "Take home",
                    centerValue: Self.money(summary.takeHomePerPeriod ?? 0),
                    thickness: 22
                )
                .frame(width: 172, height: 172)
            }
            HStack(spacing: 16) {
                legendDot(color: takeHomeColor, label: "Take home")
                legendDot(color: taxesColor,    label: "Taxes")
                legendDot(color: benefitsColor, label: "Benefits")
            }
            Text(takeHomeSummaryLine)
                .font(.system(size: 12.5))
                .foregroundColor(.incTextDim)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.incSurface))
    }

    private var takeHomeSummaryLine: AttributedString {
        let pct = summary.takeHomePct ?? 0
        let pctStr = String(format: "%.1f%%", pct)
        var attr = AttributedString("\(pctStr) of gross is yours per paycheck")
        if let range = attr.range(of: pctStr) {
            attr[range].foregroundColor = .incText
            attr[range].font = .system(size: 12.5, weight: .bold)
        }
        return attr
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.incTextDim)
        }
    }

    private func loadDetail() async {
        loadError = nil
        do {
            detail = try await viewModel.detail(for: summary.id)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private static func money(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 0
        fmt.currencyCode = "USD"
        return fmt.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}
