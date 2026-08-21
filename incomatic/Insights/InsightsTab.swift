//
//
//  InsightsTab.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Router for the Insights screen: loading → error → result → empty.
//

import SwiftUI

struct InsightsTab: View {
    let result: ViewFriendlyResponse?
    let isLoading: Bool
    let errorMessage: String?
    let onAdjust: () -> Void
    let isSignedIn: Bool
    let onShowAccount: () -> Void
    /// Saved grants for the yearly outlook's future-vest segments, and for
    /// deriving dated RSU windfalls when the budget flow is started.
    var outlookGrants: [RsuGrant] = []
    /// Reports scroll direction so the shell's floating pill nav shrinks the
    /// same way here as it does on Calculator.
    var onScrollDirectionChange: (Bool) -> Void = { _ in }
    @ObservedObject var budgetStore: BudgetStore
    let calculatorState: CalculatorState
    @ObservedObject var paydayStore: PaydayStore

    @State private var atBottom = false
    @State private var bannerDismissed = false
    @State private var showingBudgetFlow = false
    @State private var showingAnchorEditor = false
    /// Priming is offered once, immediately after the anchor is saved, which is
    /// the only moment the notification's value is self-evident.
    @State private var showingPriming = false

    // Banner is shown whenever we're at the bottom AND it hasn't been dismissed during
    // this visit. Leaving the bottom re-arms it, so it pops again next time you return.
    private var bannerBinding: Binding<Bool> {
        Binding(
            get: { atBottom && !bannerDismissed },
            set: { shown in if !shown { bannerDismissed = true } }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(.incSage)
                        Text("Calculating…").font(.system(size: 14)).foregroundColor(.incTextDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.incBg.ignoresSafeArea())
                } else if let errorMessage {
                    errorState(errorMessage)
                } else if let result = result {
                    EarningsBreakdownView(
                        result: result,
                        onAdjust: onAdjust,
                        outlookGrants: outlookGrants,
                        bottomInset: isSignedIn ? 120 : 160,   // clear the save banner + floating pill nav
                        onAtBottomChange: { value in
                            atBottom = value
                            if !value { bannerDismissed = false }   // re-arm when leaving the bottom
                        },
                        onScrollDirectionChange: onScrollDirectionChange,
                        showBudgetCTA: isSignedIn,
                        hasExistingBudget: !budgetStore.budget.goals.isEmpty || !budgetStore.budget.expenses.isEmpty,
                        onStartBudget: { showingBudgetFlow = true },
                        paydayHeader: AnyView(paydayCountdown)
                    )
                } else {
                    emptyState
                }
            }

            if result != nil, !isSignedIn {
                SaveBanner(isVisible: bannerBinding, onSignIn: onShowAccount)
                    .padding(.bottom, 96)   // clear the floating pill nav — was colliding with it
            }
        }
        // Reset bottom/dismiss tracking for each new calculation.
        .onChange(of: isLoading) { _, loading in
            if loading { atBottom = false; bannerDismissed = false }
        }
        .sheet(isPresented: $showingAnchorEditor) {
            AnchorEditSheet(
                frequency: calculatorState.payFrequency,
                net: paydayStore.netPerPeriod,
                initial: paydayStore.anchor
            ) { anchor in
                let isFirst = paydayStore.anchor == nil
                paydayStore.save(anchor)
                PaydayAnalytics.anchorSet(anchor, source: .insightsEdit, first: isFirst)
                // Only ask about notifications the first time, and only once:
                // iOS gives one shot at the system prompt.
                if isFirst && !paydayStore.primingAnswered {
                    showingPriming = true
                }
            }
        }
        .sheet(isPresented: $showingPriming) {
            NotifPrimingSheet(net: paydayStore.netPerPeriod) { _ in
                paydayStore.primingAnswered = true
            }
            .presentationDetents([.height(430)])
        }
        .fullScreenCover(isPresented: $showingBudgetFlow) {
            if let result {
                BudgetFlowView(
                    budgetStore: budgetStore,
                    calculatorState: calculatorState,
                    calculationResult: result,
                    grants: outlookGrants,
                    onClose: { showingBudgetFlow = false }
                )
            }
        }
    }

    /// Top of Insights rather than a fourth tab: one component that grows from a
    /// single line to a hero as payday approaches, so it costs nothing on the
    /// ~339 days a year when it is not interesting.
    private var paydayCountdown: some View {
        PaydayCountdown(
            anchor: paydayStore.anchor,
            net: paydayStore.netPerPeriod,
            frequency: calculatorState.payFrequency,
            onEdit: { showingAnchorEditor = true },
            onAdd: { showingAnchorEditor = true },
            onOpen: { showingAnchorEditor = true },
            onBreakdown: {}
        )
    }

    /// Shown when a calculation fails (errorMessage set, no result). Without this
    /// a failed calc — notably the first one right after onboarding — fell through
    /// to the empty "No results yet" state with no hint that anything broke.
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.incBlushBg).frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.incBlush)
            }
            Text("Couldn’t calculate")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.incText)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.incTextDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onAdjust) {
                Text("Back to Calculator")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSage))
                    .shadow(color: Color.incSage.opacity(0.3), radius: 8, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.incBg.ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.incSageBg).frame(width: 80, height: 80)
                Image(systemName: "chart.bar")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.incSage)
            }
            Text("No results yet")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.incText)
            Text("Run a calculation to see your earnings breakdown.")
                .font(.system(size: 14))
                .foregroundColor(.incTextDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onAdjust) {
                Text("Open Calculator")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSage))
                    .shadow(color: Color.incSage.opacity(0.3), radius: 8, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.incBg.ignoresSafeArea())
    }
}
