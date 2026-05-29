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
                    CalculatorFields.amountField(label: "Bonus (annual)", text: $state.bonusAmount)
                    CalculatorFields.amountField(label: "Commission (annual)", text: $state.commissionAmount)
                }
            }
            .padding(.bottom, 14)
        }
    }
}
