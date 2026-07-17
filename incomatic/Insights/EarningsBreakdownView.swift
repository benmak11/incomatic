//
//  
//  EarningsBreakdownView.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Hero donut + itemized summary + action buttons.
//  Categories driven off LineItem.category, not name matching.
//

import SwiftUI

struct EarningsBreakdownView: View {
    let result: ViewFriendlyResponse
    let onAdjust: () -> Void
    /// Saved grants driving the outlook's future-year RSU segments (§I).
    var outlookGrants: [RsuGrant] = []
    var bottomInset: CGFloat = 32
    var onAtBottomChange: (Bool) -> Void = { _ in }
    @State private var showPDFAlert = false

    // Sage palette donut
    private let takeHomeColor = Color.incSage
    private let taxesColor    = Color.incBlush
    private let benefitsColor = Color.incGold

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                IncTopBar()
                pageHeader
                netPayHero
                itemizedSummaryCard
                if let supplemental = result.supplemental {
                    supplementalCard(supplemental)
                }
                if showOutlook {
                    YearlyOutlookView(result: result, grants: outlookGrants)
                }
                actionButtons
            }
            .padding(.bottom, bottomInset)
        }
        .background(Color.incBg.ignoresSafeArea())
        .onScrollGeometryChange(for: Bool.self) { geo in
            let scrollable = geo.contentSize.height - geo.containerSize.height
            guard scrollable > 0 else { return false }
            let offsetY = geo.contentOffset.y + geo.contentInsets.top
            return offsetY >= scrollable - 24   // 24pt tolerance absorbs bounce/fractional offsets
        } action: { _, atBottom in
            onAtBottomChange(atBottom)
        }
        .refreshable {
            // Hook for future GET /v1/calculations/{id}/refresh once implemented.
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        .alert("Coming Soon", isPresented: $showPDFAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("PDF report download requires some work. It will be unveiled 🔜")
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RESULTS · \(result.grossPay.payFrequency.uppercased())")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.incSage).kerning(0.8)
            Text("Earnings breakdown")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.incText).kerning(-1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 4)
    }

    // ─ Category groupings ────────────────────────────────────
    private var earningsItems: [LineItem] {
        result.lineItems.filter { $0.category == "EARNINGS" }
    }
    private var taxItems: [LineItem] {
        result.lineItems.filter {
            $0.category == "TAX_FEDERAL" || $0.category == "TAX_FICA" || $0.category == "TAX_STATE"
        }
    }
    private var benefitItems: [LineItem] {
        result.lineItems.filter {
            $0.category == "PRE_TAX_BENEFIT" || $0.category == "RETIREMENT" || $0.category == "POST_TAX"
        }
    }
    private var earningsTotal: Double { earningsItems.reduce(0) { $0 + $1.amount } }
    private var taxesTotal:    Double { taxItems.reduce(0)    { $0 + $1.amount } }
    private var benefitsTotal: Double { benefitItems.reduce(0){ $0 + $1.amount } }
    private var netPay: Double         { result.netPay.perPayPeriod }

    private var netPayHero: some View {
        IncCard {
            VStack(spacing: 14) {
                DonutChart(
                    wedges: [
                        .init(value: netPay,        color: takeHomeColor),
                        .init(value: taxesTotal,    color: taxesColor),
                        .init(value: benefitsTotal, color: benefitsColor)
                    ],
                    centerLabel: "Take home",
                    centerValue: formatCurrency(netPay)
                )
                .frame(height: 190)

                HStack(spacing: 18) {
                    legendDot(color: takeHomeColor, label: "Take home")
                    legendDot(color: taxesColor,    label: "Taxes")
                    legendDot(color: benefitsColor, label: "Benefits")
                }

                Text("\(String(format: "%.1f", result.netPay.takeHomePercentage))% of gross is yours per \(result.grossPay.payFrequency) paycheck")
                    .font(.system(size: 12.5)).foregroundColor(.incTextDim)
                    .multilineTextAlignment(.center)
                Text("NOTE: This is just an estimate. Actual take-home pay may vary.")
                    .font(.system(size: 12.5)).foregroundColor(.incTextDim)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
    }

    /// Outlook renders only when there's something beyond flat base pay to show.
    private var showOutlook: Bool {
        result.outlookBonusAmount > 0
            || (result.supplemental?.rsuGross ?? 0) > 0
            || !outlookGrants.isEmpty
    }

    // ─ Supplemental income (server-truth, §F) ────────────────
    // ALL figures on SupplementalBreakdown are ANNUAL — this is a lump-sum view,
    // deliberately not divided by the pay cadence like the cards above it.

    /// "Mar 15" from the request's ISO bonus date; nil when undated.
    private func bonusDateLabel() -> String? {
        guard let iso = result.bonusPayoutDate, let date = VestMath.parseDate(iso) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func supplementalCard(_ supplemental: SupplementalBreakdown) -> some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.incBlushBg)
                            .frame(width: 34, height: 34)
                        Image(systemName: "gift")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.incBlush)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Supplemental income")
                            .font(.system(size: 15, weight: .bold)).foregroundColor(.incText)
                        Text("Annual · taxed at 22% supplemental")
                            .font(.system(size: 12)).foregroundColor(.incTextDim)
                    }
                    Spacer()
                }
                .padding(.bottom, 14)

                if supplemental.bonusGross > 0 {
                    bonusRow(bonusDateLabel().map { "Bonus · \($0)" } ?? "Bonus",
                             amount: supplemental.bonusGross, emphasized: false)
                }
                if supplemental.commissionGross > 0 {
                    bonusRow("Commission", amount: supplemental.commissionGross, emphasized: false)
                }
                if supplemental.rsuGross > 0 {
                    bonusRow("RSU vesting", amount: supplemental.rsuGross, emphasized: false)
                }
                divider
                bonusRow("Federal (22% supplemental)", amount: -supplemental.federalTax, emphasized: false)
                bonusRow("Social Security", amount: -supplemental.socialSecurity, emphasized: false)
                bonusRow("Medicare", amount: -supplemental.medicare, emphasized: false)
                Rectangle().fill(Color.incSageBg).frame(height: 2).padding(.vertical, 10)
                HStack {
                    Text("Net supplemental").font(.system(size: 16, weight: .semibold)).foregroundColor(.incText)
                    Spacer()
                    Text(formatCurrency(supplemental.net))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.incSage)
                        .monospacedDigit()
                }

                Text("Estimates value all \(String(AppConfig.taxYear)) vests at today's price. Actual tax withholding happens at each vest at that day's price. State tax on supplemental income is folded into the state line above.")
                    .font(.system(size: 11.5)).foregroundColor(.incTextDim)
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 16)
    }

    private func bonusRow(_ label: String, amount: Double, emphasized: Bool) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(.incTextDim)
            Spacer()
            Text(formatSigned(amount))
                .font(.system(size: 13, weight: emphasized ? .bold : .regular))
                .foregroundColor(.incText)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.incTextDim)
        }
    }

    private var itemizedSummaryCard: some View {
        IncCard {
            VStack(spacing: 0) {
                sectionRow("Earnings", amount: earningsTotal)
                ForEach(earningsItems, id: \.name) { item in
                    indentedRow(item.name, amount: item.amount)
                }
                if !taxItems.isEmpty {
                    divider
                    sectionRow("Taxes", amount: -taxesTotal)
                    ForEach(taxItems, id: \.name) { item in
                        indentedRow(item.name, amount: -item.amount)
                    }
                }
                if !benefitItems.isEmpty {
                    divider
                    sectionRow("Benefits", amount: -benefitsTotal)
                    ForEach(benefitItems, id: \.name) { item in
                        indentedRow(item.name, amount: -item.amount)
                    }
                }
                Rectangle().fill(Color.incSageBg).frame(height: 2).padding(.vertical, 10)
                takeHomeRow
            }
        }
        .padding(.horizontal, 16)
    }

    private var divider: some View {
        Rectangle().fill(Color.incHairline).frame(height: 1).padding(.vertical, 8)
    }

    private func sectionRow(_ label: String, amount: Double) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .bold)).foregroundColor(.incText)
            Spacer()
            Text(formatSigned(amount))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.incText)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private func indentedRow(_ label: String, amount: Double) -> some View {
        HStack {
            Text(label).font(.system(size: 12.5)).foregroundColor(.incTextDim).padding(.leading, 12)
            Spacer()
            Text(formatSigned(amount))
                .font(.system(size: 12.5)).foregroundColor(.incTextDim)
                .monospacedDigit()
        }
        .padding(.vertical, 3)
    }

    private var takeHomeRow: some View {
        HStack {
            Text("Take home").font(.system(size: 18, weight: .semibold)).foregroundColor(.incText)
            Spacer()
            Text(formatCurrency(netPay))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.incSage)
                .monospacedDigit()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: { showPDFAlert = true }) {
                Text("Download PDF report")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.incText)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.incHairlineStrong, lineWidth: 1.5))
            }
            Button(action: onAdjust) {
                Text("Adjust parameters")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incBtnSolid))
                    .foregroundColor(.incBtnSolidText)
            }
        }
        .padding(.horizontal, 16)
    }
}
