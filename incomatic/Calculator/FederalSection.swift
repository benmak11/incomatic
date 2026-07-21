//
//  
//  FederalSection.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//

import SwiftUI

struct FederalSection: View {
    @Bindable var state: CalculatorState

    var body: some View {
        VStack(spacing: 0) {
            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    CalculatorFields.cardHeader(icon: "person.fill", title: "Filing status")
                    CalculatorFields.radioRow(
                        "Single or Married filing separately",
                        value: FilingStatus.single,
                        selection: $state.filingStatus
                    )
                    CalculatorFields.radioRow(
                        "Married filing jointly",
                        value: FilingStatus.marriedJoint,
                        selection: $state.filingStatus
                    )
                    CalculatorFields.radioRow(
                        "Head of Household",
                        value: FilingStatus.headOfHousehold,
                        selection: $state.filingStatus
                    )
                }
            }
            .padding(.bottom, 14)

            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    CalculatorFields.cardHeader(icon: "person.2.fill", title: "W-4 details")
                    if state.useOldW4 {
                        CalculatorFields.plainNumberField(label: "Allowances",            text: $state.allowances)
                    } else {
                        CalculatorFields.amountField(label: "Dependent amount",          text: $state.dependentsAmount)
                        CalculatorFields.amountField(label: "Other income (annual)",     text: $state.otherIncome)
                        CalculatorFields.amountField(label: "Deductions",                text: $state.itemizedDeductions)
                    }
                    CalculatorFields.amountField(label: "Extra withholding / period", text: $state.additionalWithholding)
                }
            }
            .padding(.bottom, 14)

            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    CalculatorFields.cardHeader(icon: "checkmark.shield", title: "Exemptions")
                    CalculatorFields.toggleRow("Exempt from Federal Income Tax", isOn: $state.exemptFederal)
                    CalculatorFields.toggleRow("Exempt from Social Security",    isOn: $state.exemptSocialSecurity)
                    CalculatorFields.toggleRow("Exempt from Medicare",           isOn: $state.exemptMedicare)
                }
            }
            .padding(.bottom, 14)
        }
    }
}
