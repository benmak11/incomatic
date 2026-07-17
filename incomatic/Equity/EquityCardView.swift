//
//  EquityCardView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  "Equity / RSUs" card in the Earnings section (§A). Three states:
//  signed out → plain annual value field + sign-in hint; signed in without
//  grants → add CTA; signed in with grants → vesting-this-year summary.
//  An explicit manual override always wins over the grant-derived total.
//

import SwiftUI

struct EquityCardView: View {
    @Bindable var state: CalculatorState
    @ObservedObject var equity: EquityStore
    let signedIn: Bool
    let onOpenGrants: () -> Void
    let onShowAccount: () -> Void

    @State private var showOverrideField = false

    private var manualOverride: Double { Double(state.rsuVestingAmount) ?? 0 }

    var body: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                CalculatorFields.cardHeader(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Equity / RSUs",
                    sub: "Vests count as supplemental income"
                )
                if !signedIn {
                    signedOutBody
                } else if equity.grants.isEmpty {
                    emptyBody
                } else {
                    populatedBody
                }
            }
        }
    }

    // ─ Signed out ────────────────────────────────────────────

    private var signedOutBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            CalculatorFields.amountField(
                label: "RSU value vesting this year (annual)",
                text: $state.rsuVestingAmount
            )
            Button(action: onShowAccount) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.incSage)
                    Text("Sign in to model grants and vesting schedules")
                        .font(.system(size: 12))
                        .foregroundColor(.incTextDim)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // ─ Signed in, no grants ──────────────────────────────────

    private var emptyBody: some View {
        Button(action: onOpenGrants) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.incSageBg)
                        .frame(width: 34, height: 34)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.incSage)
                }
                Text("Add your RSU grants")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.incText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.incTextMute)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // ─ Signed in, grants ─────────────────────────────────────

    private var populatedBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpenGrants) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RSUs vesting in \(String(AppConfig.taxYear)) · ~\(formatWholeCurrency(equity.vestingThisYear))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(manualOverride > 0 ? .incTextMute : .incText)
                            .monospacedDigit()
                        Text("\(equity.grants.count) \(equity.grants.count == 1 ? "grant" : "grants") · \(equity.tickerSummary)")
                            .font(.system(size: 12.5))
                            .foregroundColor(.incTextDim)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.incTextMute)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)

            // Explicit override — replaces the grant-derived total, never silent.
            if showOverrideField || manualOverride > 0 {
                CalculatorFields.amountField(
                    label: "Override amount (annual)",
                    text: $state.rsuVestingAmount
                )
                if manualOverride > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.incBlush)
                        Text("Using your override — clear it to value grants automatically.")
                            .font(.system(size: 12))
                            .foregroundColor(.incTextDim)
                    }
                }
            } else {
                Button {
                    showOverrideField = true
                } label: {
                    Text("Override amount")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.incSage)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showOverrideField)
    }
}
