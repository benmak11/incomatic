//
//  OnboardingReviewView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/21/2026
//
//  Review step ending — borrowed from the Claude Design "Calm" onboarding
//  variation: a quiet serif "Projected take-home" figure above an editable
//  answer list. Tapping any row jumps back to that step. The primary CTA
//  lives in the shared OnboardingFooter, not here.
//

import SwiftUI

struct OnboardingReviewView: View {
    @Bindable var state: CalculatorState
    let onEdit: (OnboardingStep) -> Void

    private var live: LivePreview { livePreview(state: state) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let perPeriod = live.perPeriod {
                VStack(spacing: 6) {
                    Text("PROJECTED TAKE-HOME · PER \(state.payFrequency.displayName.uppercased())")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.incSage)
                        .kerning(0.8)
                        .multilineTextAlignment(.center)
                    Text(formatCurrency(perPeriod))
                        .font(.system(size: 40, weight: .medium, design: .serif))
                        .foregroundColor(.incSageDeep)
                        .kerning(-1)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 22)
            }

            IncCard {
                VStack(spacing: 0) {
                    reviewRow("Wage", value: wageValue, step: .wage)
                    divider
                    reviewRow("Pay frequency", value: state.payFrequency.displayName, step: .payFrequency)
                    divider
                    reviewRow("Bonus", value: bonusValue, step: .bonus)
                    divider
                    reviewRow("Commission", value: commissionValue, step: .commission)
                    divider
                    reviewRow("Filing status", value: state.filingStatus.displayName, step: .filingStatus)
                    divider
                    reviewRow("Work state", value: state.stateName(for: state.selectedStateCode) ?? "—", step: .state)
                    divider
                    reviewRow("Retirement", value: retirementValue, step: .retirement)
                }
            }
        }
    }

    private func reviewRow(_ label: String, value: String, step: OnboardingStep) -> some View {
        Button(action: { onEdit(step) }) {
            HStack {
                Text(label)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.incTextDim)
                Spacer()
                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.incText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.incTextMute)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle().fill(Color.incHairline).frame(height: 1)
    }

    private var wageValue: String {
        state.incomeType == .salary
            ? formatCurrency(Double(state.salaryAmount) ?? 0)
            : "\(formatCurrency(Double(state.hourlyRate) ?? 0))/hr"
    }
    private var bonusValue: String {
        (Double(state.bonusAmount) ?? 0) > 0 ? formatCurrency(Double(state.bonusAmount) ?? 0) : "None"
    }
    private var commissionValue: String {
        (Double(state.commissionAmount) ?? 0) > 0 ? formatCurrency(Double(state.commissionAmount) ?? 0) : "None"
    }
    private var retirementValue: String {
        "\(String(format: "%.1f", state.traditional401kPercent))% 401(k) · \(String(format: "%.1f", state.roth401kPercent))% Roth"
    }
}
