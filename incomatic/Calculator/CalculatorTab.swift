//
//  
//  CalculatorTab.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Orchestrator for the four-section form. CalculatorState (the @Observable
//  source of truth) is owned by ContentView and shared with onboarding, so
//  answers collected there are already in place when this tab first appears.
//

import SwiftUI
import UIKit

struct CalculatorTab: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var viewModel: SalaryCalculatorViewModel
    @ObservedObject var accountManager: AccountManager
    @ObservedObject var equityStore: EquityStore
    @Bindable var state: CalculatorState
    let onShowAccount: () -> Void
    /// The shell's active tab — threaded through so the embedded pill nav in
    /// CalculatorBottomDock can switch tabs, same as the shell's own floating
    /// AppPillNav does for Insights/History.
    @Binding var tab: MainTab
    @ObservedObject var paydayStore: PaydayStore
    /// True once this install has produced a result, which gates the banner's
    /// second pass: showing the widget preview to someone who has never seen a
    /// figure is selling a countdown to a number they do not have yet.
    var hasCalculated: Bool = false
    @State private var showGrantsSheet = false
    @State private var showingAnchorEditor = false
    @State private var keyboardVisible = false

    var body: some View {
      NavigationStack {
        let preview = livePreview(state: state)
        VStack(spacing: 0) {
            AppSectionHeader(
                title: "Calculator",
                section: $state.activeSection,
                payFrequency: state.payFrequency,
                projectedPerPeriod: preview.perPeriod
            )

            if let pass = paydayStore.bannerPass(hasCalculated: hasCalculated) {
                ExistingUserBanner(
                    pass: pass,
                    onAdd: { showingAnchorEditor = true },
                    onDismiss: {
                        paydayStore.dismissBanner(pass: pass)
                        PaydayAnalytics.promptDismissed(.banner, pass: pass)
                    }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.opacity)
                // Fires on the pass actually rendered, so pass 1 and pass 2
                // carry separate conversion rates rather than one blended one.
                .onAppear { PaydayAnalytics.promptShown(.banner, pass: pass) }
            }

            ScrollView {
                VStack(spacing: 0) {
                    switch state.activeSection {
                    case .earnings: EarningsSection(
                        state: state,
                        equity: equityStore,
                        signedIn: accountManager.isSignedIn,
                        onOpenGrants: { showGrantsSheet = true },
                        onShowAccount: onShowAccount
                    )
                    case .federal:  FederalSection(state: state)
                    case .state:    StateSection(state: state)
                    case .benefits: BenefitsSection(state: state)
                    }
                }
                .padding(.horizontal, 16)
                .id(state.activeSection)  // re-mount for animation
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                // Hidden only while the keyboard is up so it doesn't crowd the
                // field being edited. safeAreaInset auto-reserves exactly the
                // space this view needs, so scroll content never needs a
                // hand-tuned bottom-padding guess.
                if !keyboardVisible {
                    CalculatorBottomDock(
                        activeSection: $state.activeSection,
                        tab: $tab,
                        isLoading: viewModel.isLoading,
                        canCalculate: state.canCalculate,
                        needsRecalculation: state.needsRecalculation,
                        onCalculate: triggerCalculation
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // .decimalPad has no return key. One Done bar for the whole screen —
            // every section's numeric fields share this ScrollView's hosting context.
            .keyboardDoneToolbar()
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { keyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { keyboardVisible = false }
            }
        }
        .background(Color.incBg.ignoresSafeArea())
        .sheet(isPresented: $showingAnchorEditor) {
            AnchorEditSheet(
                frequency: state.payFrequency,
                net: paydayStore.netPerPeriod,
                initial: paydayStore.anchor
            ) { anchor in
                let isFirst = paydayStore.anchor == nil
                paydayStore.save(anchor)
                PaydayAnalytics.anchorSet(anchor, source: .banner, first: isFirst)
                // Saving from here retires the banner: the ask has been answered.
                paydayStore.bannerRetired = true
            }
        }
        .sheet(isPresented: $showGrantsSheet) {
            GrantsSheet(store: equityStore, onChanged: syncGrantDerivedRsu)
        }
        .animation(.easeInOut(duration: 0.35), value: state.activeSection)
        .task { await loadStatesFromApi() }
        // ContentView owns loading/clearing the store; any grants change
        // (initial load, sheet edits, sign-out) re-derives the vesting total.
        .onReceive(equityStore.$grants) { _ in
            syncGrantDerivedRsu()
        }
        // Bonus date/toggle edits that move it in or out of this year's paycheck
        // stale the current result (§3) — same nudge as grant edits.
        .onChange(of: state.bonusIncludedThisYear) {
            if viewModel.calculationResult != nil {
                state.needsRecalculation = true
            }
        }
        .onChange(of: locationManager.state) { _, newState in
            if let match = state.statesList.first(where: { $0.name == newState }) {
                state.selectedStateCode = match.code
            }
        }
        .toolbar(.hidden, for: .navigationBar)
      }
    }

    /// Push the grant-derived vesting total into the calculator state; if it
    /// changed after a result exists, surface the "Recalculate" nudge.
    private func syncGrantDerivedRsu() {
        let derived = equityStore.vestingThisYear
        guard derived != state.grantDerivedRsuAnnual else { return }
        state.grantDerivedRsuAnnual = derived
        if viewModel.calculationResult != nil {
            state.needsRecalculation = true
        }
    }

    private func loadStatesFromApi() async {
        state.statesList = await loadUSStates()
    }

    private func triggerCalculation() {
        state.needsRecalculation = false
        let built = buildCalculationRequest(state: state)
        Task {
            await viewModel.calculateSalary(
                request: built.request,
                baseSalaryAnnual: built.baseAnnual,
                bonusAnnual: built.bonusAnnual,
                benefits: built.benefits
            )
        }
    }
}

