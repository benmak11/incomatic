//
//  YearlyOutlookView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  Yearly earnings outlook (§I): collapsed pill → expanded year rows with
//  stacked base (sage) + bonus (blush) + RSU (gold) bars. All math is local:
//  base held flat, one-time bonus in its payout year / recurring from its
//  start year onward, RSU vests at today's price. GROSS figures, labeled so.
//  Clamped to the current tax year — past vest years never appear.
//  The caption text ("Base … · +Bonus … · +RSU …") is the accessible channel;
//  the colored segments are reinforcement only.
//

import SwiftUI

struct YearlyOutlookView: View {
    let result: ViewFriendlyResponse
    let grants: [RsuGrant]

    @State private var expanded = false
    @State private var showAllYears = false

    private static let visibleYearCap = 6

    // ─ Year math ─────────────────────────────────────────────

    struct YearEntry: Identifiable {
        let year: Int
        let base: Double
        let bonus: Double
        let rsu: Double
        var total: Double { base + bonus + rsu }
        /// Non-base share of total (the outlook's percentage semantics).
        var nonBasePct: Double { total > 0 ? (bonus + rsu) / total * 100 : 0 }
        var id: Int { year }
    }

    private var bonusStartYear: Int {
        result.bonusPayoutDate.flatMap { VestMath.parseDate($0) }
            .map { Calendar.current.component(.year, from: $0) } ?? AppConfig.taxYear
    }

    private func bonus(in year: Int) -> Double {
        guard result.outlookBonusAmount > 0 else { return 0 }
        let applies = result.outlookBonusRecurring ? year >= bonusStartYear : year == bonusStartYear
        return applies ? result.outlookBonusAmount : 0
    }

    private func rsu(in year: Int) -> Double {
        // Current year is server-truth (includes any explicit override that was
        // sent on the request); future years derive from the vest schedules.
        if year == AppConfig.taxYear {
            return result.supplemental?.rsuGross ?? 0
        }
        return VestMath.value(inYear: year, grants: grants)
    }

    private var entries: [YearEntry] {
        // First year = current tax year (never past years, even when vests exist
        // there); last = final vest year or bonus start year, whichever is later.
        let firstYear = AppConfig.taxYear
        var lastYear = max(
            VestMath.finalVestYear(grants: grants) ?? firstYear,
            result.outlookBonusAmount > 0 ? bonusStartYear : firstYear
        )
        lastYear = max(lastYear, firstYear + 1)   // min 2 rows
        return (firstYear...lastYear).map { year in
            YearEntry(
                year: year,
                base: result.grossPay.baseAnnual,
                bonus: bonus(in: year),
                rsu: rsu(in: year)
            )
        }
    }

    private var visibleEntries: [YearEntry] {
        showAllYears ? entries : Array(entries.prefix(Self.visibleYearCap))
    }

    /// The year with the highest non-base share — the collapsed pill's headline.
    private var highlightEntry: YearEntry? {
        entries.filter { $0.bonus + $0.rsu > 0 }.max { $0.nonBasePct < $1.nonBasePct }
    }

    private var hasBonusAnywhere: Bool { entries.contains { $0.bonus > 0 } }
    private var hasRsuAnywhere: Bool { entries.contains { $0.rsu > 0 } }

    private var nonBaseLabel: String {
        switch (hasBonusAnywhere, hasRsuAnywhere) {
        case (true, true):  return "Bonus + RSUs add up to"
        case (true, false): return "Bonus adds up to"
        default:            return "RSUs add up to"
        }
    }

    var body: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                header
                if expanded {
                    VStack(spacing: 4) {
                        ForEach(visibleEntries) { entry in
                            yearRow(entry)
                        }
                    }
                    .padding(.top, 12)
                    if entries.count > Self.visibleYearCap && !showAllYears {
                        Button {
                            showAllYears = true
                        } label: {
                            Text("+\(entries.count - Self.visibleYearCap) more years")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.incSage)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    assumptionsCaption
                        .padding(.top, 12)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: expanded)
        }
        .padding(.horizontal, 16)
    }

    // ─ Collapsed pill / header ───────────────────────────────

    private var header: some View {
        Button {
            expanded.toggle()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.incSageBg)
                        .frame(width: 34, height: 34)
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.incSage)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Yearly earnings outlook · \(String(entries.first?.year ?? AppConfig.taxYear))–\(String(entries.last?.year ?? AppConfig.taxYear))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.incText)
                        .monospacedDigit()
                    if let top = highlightEntry {
                        Text("\(nonBaseLabel) \(Int(top.nonBasePct.rounded()))% in \(String(top.year)) · gross")
                            .font(.system(size: 12))
                            .foregroundColor(.incTextDim)
                    } else {
                        Text("Gross earnings, before taxes and deductions")
                            .font(.system(size: 12))
                            .foregroundColor(.incTextDim)
                    }
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.incTextMute)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
    }

    // ─ Year rows ─────────────────────────────────────────────

    private var maxTotal: Double {
        max(entries.map(\.total).max() ?? 1, 1)
    }

    private func yearRow(_ entry: YearEntry) -> some View {
        let isCurrent = entry.year == AppConfig.taxYear
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(String(entry.year))
                    .font(.system(size: 13, weight: isCurrent ? .bold : .semibold))
                    .foregroundColor(.incText)
                    .monospacedDigit()
                if isCurrent {
                    Text("THIS YEAR'S PAYCHECK CALC")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.incSageDeep)
                        .kerning(0.5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.incSageBg))
                }
                Spacer()
                Text(formatWholeCurrency(entry.total))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.incText)
                    .monospacedDigit()
            }
            stackedBar(entry)
            captionRow(entry)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func stackedBar(_ entry: YearEntry) -> some View {
        GeometryReader { geo in
            let width = geo.size.width * (entry.total / maxTotal)
            HStack(spacing: 1.5) {
                if entry.base > 0 {
                    Capsule().fill(Color.incSage)
                        .frame(width: max(3, width * (entry.base / entry.total)))
                }
                if entry.bonus > 0 {
                    Capsule().fill(Color.incBlush)
                        .frame(width: max(3, width * (entry.bonus / entry.total)))
                }
                if entry.rsu > 0 {
                    Capsule().fill(Color.incGold)
                        .frame(width: max(3, width * (entry.rsu / entry.total)))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)   // caption row carries the values
    }

    private func captionRow(_ entry: YearEntry) -> some View {
        var parts: [String] = ["Base \(formatWholeCurrency(entry.base))"]
        if entry.bonus > 0 { parts.append("+Bonus \(formatWholeCurrency(entry.bonus))") }
        if entry.rsu > 0 { parts.append("+RSU \(formatWholeCurrency(entry.rsu))") }
        let pct = entry.bonus + entry.rsu > 0 ? " (\(Int(entry.nonBasePct.rounded()))%)" : ""
        return Text(parts.joined(separator: " · ") + pct)
            .font(.system(size: 11))
            .foregroundColor(.incTextDim)
            .monospacedDigit()
    }

    // ─ Assumptions ───────────────────────────────────────────

    private var assumptionsCaption: some View {
        var clauses = ["Base pay held flat at \(formatWholeCurrency(result.grossPay.baseAnnual))/yr."]
        if hasBonusAnywhere {
            clauses.append(result.outlookBonusRecurring
                ? "Bonus repeats every year at the same amount."
                : "Bonus shown once, in its payout year.")
        }
        if hasRsuAnywhere {
            clauses.append("RSU value uses today's price for every future vest — actual value will differ.")
        }
        clauses.append("All figures gross, before taxes and deductions.")
        return Text(clauses.joined(separator: " "))
            .font(.system(size: 11.5))
            .foregroundColor(.incTextDim)
            .fixedSize(horizontal: false, vertical: true)
    }
}
