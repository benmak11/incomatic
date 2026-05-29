//
//  
//  BenefitsSection.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//

import SwiftUI

struct BenefitsSection: View {
    @Bindable var state: CalculatorState

    var body: some View {
        VStack(spacing: 0) {
            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    CalculatorFields.cardHeader(
                        icon: "heart.text.square",
                        title: "Pre-tax benefits",
                        sub: "Per \(state.payFrequency.displayName.lowercased()) period"
                    )
                    CalculatorFields.amountField(label: "Medical",            text: $state.medicalPerPeriod)
                    CalculatorFields.amountField(label: "Dental",             text: $state.dentalPerPeriod)
                    CalculatorFields.amountField(label: "Vision",             text: $state.visionPerPeriod)
                    CalculatorFields.amountField(label: "Healthcare FSA",     text: $state.healthcareFsaPerPeriod)
                    CalculatorFields.amountField(label: "Dependent care FSA", text: $state.dependentCareFsaPerPeriod)
                    CalculatorFields.amountField(label: "Healthcare HSA",     text: $state.hsaPerPeriod)
                }
            }
            .padding(.bottom, 14)

            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    CalculatorFields.cardHeader(
                        icon: "lock.shield.fill",
                        title: "Retirement",
                        sub: "% of gross pay"
                    )
                    percentRow(
                        label: "TRADITIONAL 401(K)",
                        value: state.traditional401kPercent,
                        binding: $state.traditional401kPercent
                    )
                    .padding(.bottom, 18)
                    percentRow(
                        label: "ROTH 401(K)",
                        value: state.roth401kPercent,
                        binding: $state.roth401kPercent
                    )
                }
            }
            .padding(.bottom, 14)

            IncCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        CalculatorFields.cardHeader(icon: "doc.text", title: "Custom deductions")
                        Spacer()
                        Button(action: { state.customDeductions.append(CustomDeduction()) }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.incSage).font(.title3)
                        }
                    }
                    if state.customDeductions.isEmpty {
                        Text("Tap + to add post-tax line items (annual amounts).")
                            .font(.system(size: 12)).foregroundColor(.incTextDim)
                    }
                    ForEach($state.customDeductions) { $deduction in
                        customDeductionRow($deduction)
                    }
                }
            }
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private func percentRow(label: String, value: Double, binding: Binding<Double>) -> some View {
        HStack(alignment: .firstTextBaseline) {
            CalculatorFields.fieldLabel(label)
            Spacer()
            Text("\(String(format: "%.1f", value))%")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.incSage)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Capsule().fill(Color.incSageBg))
        }
        Slider(value: binding, in: 0...25, step: 0.5)
            .tint(.incSage)
    }

    @ViewBuilder
    private func customDeductionRow(_ deduction: Binding<CustomDeduction>) -> some View {
        HStack(spacing: 10) {
            TextField("Name", text: deduction.name)
                .font(.system(size: 13))
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.incSageBg).cornerRadius(10)
            HStack(spacing: 4) {
                Text("$").foregroundColor(.incTextMute).font(.system(size: 13))
                TextField("0.00", text: deduction.amount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 13))
                    .frame(width: 84)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color.incSageBg).cornerRadius(10)
            Button(action: {
                state.customDeductions.removeAll { $0.id == deduction.wrappedValue.id }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14)).foregroundColor(.incTextMute)
            }
        }
    }
}
