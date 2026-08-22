//
//  
//  StateSection.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//

import SwiftUI

struct StateSection: View {
    @Bindable var state: CalculatorState

    var body: some View {
        VStack(spacing: 0) {
            IncCard {
                VStack(alignment: .leading, spacing: 0) {
                    CalculatorFields.cardHeader(icon: "mappin.circle.fill", title: "Where you work")
                    VStack(alignment: .leading, spacing: 0) {
                        CalculatorFields.fieldLabel("STATE OR TERRITORY")
                        CalculatorFields.styledMenu(
                            label: state.stateName(for: state.selectedStateCode) ?? "Select state"
                        ) {
                            ForEach(state.statesList) { entry in
                                Button(entry.name) { state.selectedStateCode = entry.code }
                            }
                        }
                    }
                    .padding(.bottom, 18)

                    CalculatorFields.toggleRow(
                        "Resides in a different state",
                        sub: "Splits work-state and home-state withholding",
                        isOn: $state.livesInDifferentState
                    )

                    if state.livesInDifferentState {
                        VStack(alignment: .leading, spacing: 0) {
                            CalculatorFields.fieldLabel("STATE OF RESIDENCE")
                            CalculatorFields.styledMenu(
                                label: state.stateName(for: state.resideStateCode) ?? "Select state"
                            ) {
                                ForEach(state.statesList) { entry in
                                    Button(entry.name) {
                                        state.resideStateCode = entry.code
                                        state.selectedStateCode = entry.code
                                    }
                                }
                            }
                        }
                        .padding(.top, 8).padding(.bottom, 14)
                        CalculatorFields.toggleRow(
                            "Non-residency certificate filed",
                            isOn: $state.nonResidencyCertificate
                        )
                    }

                    if state.selectedStateCode == "MD" {
                        VStack(alignment: .leading, spacing: 0) {
                            CalculatorFields.fieldLabel("MARYLAND COUNTY")
                            CalculatorFields.styledMenu(label: state.mdCounty) {
                                ForEach(
                                    ["Anne Arundel", "Baltimore City", "Baltimore", "Howard",
                                     "Montgomery", "Prince George's"],
                                    id: \.self
                                ) { c in
                                    Button(c) { state.mdCounty = c }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.bottom, 14)

            rulePackCallout
        }
    }

    private var rulePackCallout: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.incSurface).frame(width: 36, height: 36)
                Image(systemName: "info.circle.fill").foregroundColor(.incBlush).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 4) {
                // Was a hardcoded "Rule pack 2025.11", which went stale the
                // moment the pack was bumped and the client has no way to know
                // the minor version anyway. The callout is about multi-state
                // withholding, so it says that instead of a version.
                Text("Multi-state withholding")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.incText)
                Text("Multi-state withholding split applies the work-state rate. Your state of residence still files an annual return.")
                    .font(.system(size: 12.5)).foregroundColor(.incTextDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.incBlushBg)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.bottom, 14)
    }
}
