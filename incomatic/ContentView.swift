//
//  ContentView.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//
//  Root view: gates first-run Guided Notebook onboarding, then hosts the
//  persistent shell (Calculator + Insights + History switched by a floating
//  pill nav, per the Incomatic v2.0 handoff). Owns AccountManager +
//  AccountSheet, and routes to Insights when a calculation completes.
//

import StoreKit
import SwiftUI

struct ContentView: View {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = SalaryCalculatorViewModel()
    @StateObject private var accountManager = AccountManager()
    @StateObject private var historyViewModel = HistoryViewModel()
    @StateObject private var equityStore = EquityStore()
    @StateObject private var budgetStore = BudgetStore()
    @StateObject private var paydayStore = PaydayStore()
    /// Shared with onboarding so answers collected there are already in
    /// place once the Calculator tab is reachable.
    @State private var calculatorState = CalculatorState()
    @State private var selectedTab: MainTab = .calculator
    @State private var showingAccountSheet = false
    @State private var toastMessage: String?
    @State private var pillNavCompact = false
    @State private var showingAnchorReveal = false
    @State private var showingPriming = false
    @AppStorage("incomatic.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainShell
            } else {
                OnboardingNotebookView(
                    state: calculatorState,
                    userName: accountManager.currentUser?.displayName?
                        .components(separatedBy: " ").first,
                    onCalculate: finishOnboarding
                )
            }
        }
        .sheet(isPresented: $showingAccountSheet) {
            AccountSheet(
                accountManager: accountManager,
                savedCount: historyViewModel.sessions.count,
                onClose: { showingAccountSheet = false }
            )
        }
        .task {
            viewModel.attach(accountManager: accountManager)
            historyViewModel.attach(accountManager: accountManager)
            equityStore.attach(accountManager: accountManager)
            budgetStore.attach(accountManager: accountManager)
            accountManager.restoreSession()
            if accountManager.isSignedIn {
                await historyViewModel.load()
                await equityStore.load()
                await budgetStore.load()
            }
        }
        .onChange(of: viewModel.isLoading) { _, loading in
            if !loading, let result = viewModel.calculationResult {
                selectedTab = .insights
                // The widget and the notification body both read this, so it has
                // to be recorded on every calculation rather than only the first.
                paydayStore.recordNet(result.netPay.perPayPeriod,
                                      frequency: calculatorState.payFrequency)
                // Candidate A: ask for the payday while the figure they came for
                // is still on screen. Once per install, and never after
                // onboarding already asked.
                if paydayStore.shouldAskOnReveal {
                    showingAnchorReveal = true
                    PaydayAnalytics.promptShown(.reveal)
                }
                if accountManager.isSignedIn {
                    Task {
                        await historyViewModel.load()
                        showToast("Saved to History")
                    }
                }
                Analytics.shared.track(AnalyticsEventName.calculationCompleted,
                                      properties: calculationProperties())
                // A completed calculation is the state most worth not losing.
                CalculatorStatePersistence.save(calculatorState)
                if ReviewPromptManager.recordSuccessfulCalculation() {
                    requestReview()
                }
            }
        }
        .fullScreenCover(isPresented: $showingAnchorReveal) {
            PaydayAnchorRevealView(
                net: viewModel.calculationResult?.netPay.perPayPeriod ?? 0,
                frequency: calculatorState.payFrequency
            ) { anchor in
                if let anchor {
                    let isFirst = paydayStore.anchor == nil
                    paydayStore.revealAsked = true
                    paydayStore.save(anchor)
                    PaydayAnalytics.anchorSet(anchor, source: .reveal, first: isFirst)
                    // The anchor is the precondition for the notification being
                    // worth anything, so priming follows immediately while the
                    // reason is still obvious.
                    if !paydayStore.primingAnswered { showingPriming = true }
                } else {
                    paydayStore.declineReveal()
                    PaydayAnalytics.promptDismissed(.reveal)
                }
                showingAnchorReveal = false
            }
        }
        .sheet(isPresented: $showingPriming) {
            NotifPrimingSheet(net: paydayStore.netPerPeriod) { _ in
                paydayStore.primingAnswered = true
            }
            .presentationDetents([.height(430)])
        }
        .onChange(of: selectedTab) { _, _ in
            pillNavCompact = false
        }
        .onAppear {
            // Signed-in batches get attributed to an accountId server-side; signed-out
            // ones still arrive, keyed on deviceId, which is what keeps the top of the
            // funnel visible.
            Analytics.shared.sessionTokenProvider = { [weak accountManager] in
                accountManager?.sessionToken
            }
            // Before the first render, so a returning user never sees an empty form.
            CalculatorStatePersistence.restore(into: calculatorState)
        }
        .onChange(of: scenePhase) { _, phase in
            // Covers backgrounding, the app switcher, and termination from either.
            if phase != .active {
                CalculatorStatePersistence.save(calculatorState)
            }
        }
        .onChange(of: accountManager.isSignedIn) { _, signedIn in
            if signedIn {
                Task {
                    await historyViewModel.load()
                    await equityStore.load()
                    await budgetStore.load()
                }
            } else {
                historyViewModel.clearForSignOut()
                equityStore.clear()
                budgetStore.clear()
            }
        }
    }

    private var mainShell: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .calculator:
                    CalculatorTab(
                        locationManager: locationManager,
                        viewModel: viewModel,
                        accountManager: accountManager,
                        equityStore: equityStore,
                        state: calculatorState,
                        onShowAccount: { showingAccountSheet = true },
                        tab: $selectedTab,
                        paydayStore: paydayStore,
                        hasCalculated: viewModel.calculationResult != nil
                    )
                case .insights:
                    InsightsTab(
                        result: viewModel.calculationResult,
                        isLoading: viewModel.isLoading,
                        errorMessage: viewModel.errorMessage,
                        onAdjust: { selectedTab = .calculator },
                        isSignedIn: accountManager.isSignedIn,
                        onShowAccount: { showingAccountSheet = true },
                        outlookGrants: equityStore.grants,
                        onScrollDirectionChange: { down in pillNavCompact = down },
                        budgetStore: budgetStore,
                        calculatorState: calculatorState,
                        paydayStore: paydayStore
                    )
                case .history:
                    HistoryTab(
                        accountManager: accountManager,
                        viewModel: historyViewModel,
                        onShowAccount: { showingAccountSheet = true },
                        onScrollDirectionChange: { down in pillNavCompact = down }
                    )
                }
            }

            // Calculator embeds its own copy of AppPillNav inside
            // CalculatorBottomDock (combined with the CTA, to fix the
            // overlap this floating copy used to cause there); this
            // floating instance now only serves Insights/History.
            if selectedTab != .calculator {
                AppPillNav(tab: $selectedTab, compact: pillNavCompact, onExpandTap: { pillNavCompact = false })
            }
        }
        .overlay(alignment: .topTrailing) {
            AccountGlyph(
                signedIn: accountManager.isSignedIn,
                user: accountManager.currentUser,
                action: { showingAccountSheet = true }
            )
            .padding(.top, 8)
            .padding(.trailing, AccountGlyph.trailingInset)
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                SavedToast(text: toastMessage)
                    .padding(.bottom, 100)
            }
        }
    }

    /// Wraps up onboarding: locks the gate so it never shows again, then runs
    /// the same request-build + calculate flow CalculatorTab's CTA uses. The
    /// shell mounts straight onto Insights already showing its "Calculating…"
    /// spinner — we land there and flip isLoading on synchronously so the first
    /// render is the spinner, not a flash of the empty Calculator tab (or the
    /// Insights empty state) before the result routes over.
    /// Bucketed only. The client cannot pass a `Double` to `track`, and the
    /// backend rejects amount-bearing keys that are not strings, so a raw salary
    /// has to get past two independent guards to reach the analytics store.
    private func calculationProperties() -> [String: String] {
        var properties: [String: String] = [
            "state": calculatorState.selectedStateCode,
            "filing_status": String(describing: calculatorState.filingStatus),
            "pay_frequency": String(describing: calculatorState.payFrequency),
            "signed_in": accountManager.isSignedIn ? "true" : "false",
        ]
        if let net = viewModel.calculationResult?.netPay.perPayPeriod {
            properties["net_pay_bucket"] = Analytics.bucket(net)
        }
        return properties
    }

    private func finishOnboarding(anchor: PayAnchor?) {
        // Saved before the calculation so the countdown is already live when
        // Insights appears with the first result.
        if let anchor, anchor.isComplete {
            let isFirst = paydayStore.anchor == nil
            paydayStore.save(anchor)
            PaydayAnalytics.anchorSet(anchor, source: .onboarding, first: isFirst)
        }
        // Onboarding just asked (candidate C), so the results reveal must not
        // ask again on the calculation it is about to kick off. A exists to
        // reach the install base that never sees onboarding.
        paydayStore.revealAsked = true
        Analytics.shared.track(AnalyticsEventName.onboardingCompleted)
        CalculatorStatePersistence.save(calculatorState)
        hasCompletedOnboarding = true
        selectedTab = .insights
        viewModel.isLoading = true
        let built = buildCalculationRequest(state: calculatorState)
        Task {
            await viewModel.calculateSalary(
                request: built.request,
                baseSalaryAnnual: built.baseAnnual,
                bonusAnnual: built.bonusAnnual,
                benefits: built.benefits
            )
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.25)) { toastMessage = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.easeIn(duration: 0.25)) { toastMessage = nil }
        }
    }
}

#Preview {
    ContentView()
}
