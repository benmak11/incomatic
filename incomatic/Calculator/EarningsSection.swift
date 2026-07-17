//
//  
//  EarningsSection.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//

import SwiftUI

struct EarningsSection: View {
    @Bindable var state: CalculatorState
    @ObservedObject var equity: EquityStore
    let signedIn: Bool
    let onOpenGrants: () -> Void
    let onShowAccount: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    CalculatorFields.cardHeader(
                        icon: "calendar",
                        title: "Pay frequency",
                        sub: "When your paycheck lands"
                    )
                    CalculatorFields.styledMenu(label: state.payFrequency.displayName) {
                        ForEach(PayFrequency.allCases, id: \.self) { f in
                            Button(f.displayName) { state.payFrequency = f }
                        }
                    }
                }
            }
            .padding(.bottom, 14)

            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    CalculatorFields.cardHeader(icon: "creditcard", title: "How you're paid")
                    Picker("Income Type", selection: $state.incomeType) {
                        ForEach(IncomeType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 18)
                    .colorMultiply(.incSage)

                    if state.incomeType == .salary {
                        CalculatorFields.amountField(
                            label: "Gross amount",
                            text: $state.salaryAmount,
                            suffix: state.salaryBasis.displayName
                        )
                        VStack(alignment: .leading, spacing: 0) {
                            CalculatorFields.fieldLabel("METHOD")
                            CalculatorFields.styledMenu(label: state.salaryBasis.displayName) {
                                ForEach(SalaryBasis.allCases, id: \.self) { b in
                                    Button(b.displayName) { state.salaryBasis = b }
                                }
                            }
                        }
                        .padding(.bottom, 18)
                    } else {
                        CalculatorFields.amountField(label: "Hourly rate", text: $state.hourlyRate)
                        CalculatorFields.plainNumberField(
                            label: "Regular hours / period",
                            text: $state.regularHoursPerPeriod,
                            placeholder: "80"
                        )
                        CalculatorFields.plainNumberField(
                            label: "Overtime hours / period (1.5×)",
                            text: $state.overtimeHoursPerPeriod
                        )
                    }
                }
            }
            .padding(.bottom, 14)

            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    CalculatorFields.cardHeader(
                        icon: "gift",
                        title: "Bonus & commission",
                        sub: "Taxed at 22% supplemental"
                    )
                    CalculatorFields.amountField(
                        label: "Bonus",
                        text: $state.bonusAmount,
                        suffix: "Lump sum"
                    )
                    if hasBonus {
                        bonusDateRow
                        CalculatorFields.toggleRow(
                            "Repeats yearly",
                            sub: "Same amount every year from its start year",
                            isOn: $state.bonusRecurring
                        )
                        if let caption = bonusInclusionCaption {
                            inclusionNote(caption)
                        }
                    }
                    CalculatorFields.amountField(label: "Commission (annual)", text: $state.commissionAmount)
                }
                .animation(.easeInOut(duration: 0.2), value: hasBonus)
                .animation(.easeInOut(duration: 0.2), value: bonusInclusionCaption)
            }
            .padding(.bottom, 14)

            EquityCardView(
                state: state,
                equity: equity,
                signedIn: signedIn,
                onOpenGrants: onOpenGrants,
                onShowAccount: onShowAccount
            )
            .padding(.bottom, 14)
        }
    }

    // ─ Dated lump-sum bonus (§H) ─────────────────────────────

    private var hasBonus: Bool { (Double(state.bonusAmount) ?? 0) > 0 }

    private var bonusStartYear: Int? { state.bonusStartYear }

    /// Inline note when the bonus start year keeps it out of this year's paycheck.
    /// Nil date = assumed current tax year; recurring bonuses started in the past
    /// are included, so neither case gets a caption.
    private var bonusInclusionCaption: String? {
        guard let year = bonusStartYear, year != AppConfig.taxYear else { return nil }
        if state.bonusRecurring {
            return year > AppConfig.taxYear
                ? "Starts in \(String(year)) — repeats every year after."
                : nil
        }
        return year > AppConfig.taxYear
            ? "Lands in \(String(year)) — shown in your yearly outlook, not this year's paycheck."
            : "Landed in \(String(year)) — not in this year's paycheck."
    }

    private var bonusDateRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            CalculatorFields.fieldLabel("PAID ON")
            HStack {
                if let date = state.bonusDate {
                    DatePicker(
                        "Bonus payout date",
                        selection: Binding(
                            get: { date },
                            set: { state.bonusDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(.incSage)
                    Spacer()
                    Button { state.bonusDate = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.incTextMute)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear payout date — assume this year")
                } else {
                    Button { state.bonusDate = Date() } label: {
                        HStack(spacing: 8) {
                            Text("This year")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.incTextDim)
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.incSage)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Paid on: this year. Tap to pick a date")
                }
            }
            .padding(.bottom, 8)
            .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
        }
        .padding(.bottom, 18)
    }

    private func inclusionNote(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.incBlush)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.incTextDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 14)
    }
}
