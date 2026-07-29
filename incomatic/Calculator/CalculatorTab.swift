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
    /// Reports scroll direction so the shell's floating pill nav can shrink
    /// out of the way while filling out a long section, like the native
    /// tab bar's onScrollDown minimize behavior.
    var onScrollDirectionChange: (Bool) -> Void = { _ in }
    @State private var showGrantsSheet = false
    @State private var keyboardVisible = false
    @State private var scrollProgress: CGFloat = 0   // 0 at top → 1 at bottom

    var body: some View {
      NavigationStack {
        ZStack(alignment: .bottom) {
            Color.incBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    AppSectionHeader(title: "Calculator", section: $state.activeSection)

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
                    .padding(.bottom, 210)   // sticky CTA + floating pill-nav clearance
                    .id(state.activeSection)  // re-mount for animation
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                let scrollable = geo.contentSize.height - geo.containerSize.height
                // Non-scrollable section = whole form already visible = fully revealed.
                guard scrollable > 0 else { return 1 }
                let offsetY = geo.contentOffset.y + geo.contentInsets.top
                return min(max(offsetY / scrollable, 0), 1)
            } action: { old, progress in
                // No withAnimation: opacity must track the finger frame-by-frame.
                scrollProgress = progress
                if progress <= 0.02 {
                    onScrollDirectionChange(false)   // back at the top — always expanded
                } else if progress > old + 0.004 {
                    onScrollDirectionChange(true)    // scrolling down — shrink
                } else if progress < old - 0.004 {
                    onScrollDirectionChange(false)   // scrolling up — expand
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

            // Sticky CTA: always pinned above the tab bar; hidden only while the keyboard
            // is up so it doesn't crowd the field being edited.
            if !keyboardVisible {
                let preview = livePreview(state: state)
                VStack(spacing: 8) {
                if state.needsRecalculation && state.canCalculate {
                    recalcNudge
                }
                StickyProgressCTA(
                    activeSection: $state.activeSection,
                    isLoading: viewModel.isLoading,
                    canCalculate: state.canCalculate,
                    payFrequency: state.payFrequency,
                    projectedPerPeriod: preview.perPeriod,
                    projectedPct: preview.pctOfGross,
                    onCalculate: triggerCalculation,
                    scrollProgress: scrollProgress
                )
                }
                .padding(.bottom, 96)   // float above the pill nav
                .transition(.move(edge: .bottom).combined(with: .opacity))
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

    private var recalcNudge: some View {
        Button(action: triggerCalculation) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .bold))
                Text("Inputs changed — recalculate to update your results")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundColor(.incSageDeep)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.incSageBg))
            .overlay(Capsule().strokeBorder(Color.incSage.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

