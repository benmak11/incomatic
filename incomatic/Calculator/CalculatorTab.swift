//
//  
//  CalculatorTab.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Orchestrator for the four-section form. Owns CalculatorState (the @Observable
//  source of truth) and the SalaryCalculatorService used to load US states.
//

import SwiftUI
import UIKit

struct CalculatorTab: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var viewModel: SalaryCalculatorViewModel
    @ObservedObject var accountManager: AccountManager
    let onShowAccount: () -> Void
    @State private var state = CalculatorState()
    @State private var ctaVisible = false

    private let service = SalaryCalculatorService()

    var body: some View {
      NavigationStack {
        ZStack(alignment: .bottom) {
            Color.incBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    IncTopBar {
                        AccountGlyph(
                            signedIn: accountManager.isSignedIn,
                            user: accountManager.currentUser,
                            action: onShowAccount
                        )
                    }
                    SectionStepIndicator(active: $state.activeSection)
                        .padding(.horizontal, 22)
                    pageHeadline

                    VStack(spacing: 0) {
                        switch state.activeSection {
                        case .earnings: EarningsSection(state: state)
                        case .federal:  FederalSection(state: state)
                        case .state:    StateSection(state: state)
                        case .benefits: BenefitsSection(state: state)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)   // tab-bar clearance; CTA only renders on demand
                    .id(state.activeSection)  // re-mount for animation
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                // .decimalPad has no return key. Add a Done button above the keypad
                // so users can dismiss it after entering amounts. Applies to every
                // numeric field in every section because the ScrollView wraps them all.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.incText)
                }
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                // Surface the CTA when the user has scrolled to (or near) the bottom
                // of the section. 60pt threshold so it appears just before the very
                // last row, not only at the exact pixel-bottom.
                let bottomEdge = geometry.contentOffset.y + geometry.containerSize.height
                let threshold: CGFloat = 60
                return bottomEdge >= geometry.contentSize.height - threshold
            } action: { _, atBottom in
                guard ctaVisible != atBottom else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    ctaVisible = atBottom
                }
            }

            if ctaVisible {
                let preview = livePreview(state: state)
                StickyProgressCTA(
                    activeSection: $state.activeSection,
                    isLoading: viewModel.isLoading,
                    canCalculate: state.canCalculate,
                    payFrequency: state.payFrequency,
                    projectedPerPeriod: preview.perPeriod,
                    projectedPct: preview.pctOfGross,
                    onCalculate: triggerCalculation
                )
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: state.activeSection)
        .task { await loadStatesFromApi() }
        .onChange(of: locationManager.state) { _, newState in
            if let match = state.statesList.first(where: { $0.name == newState }) {
                state.selectedStateCode = match.code
            }
        }
        .toolbar(.hidden, for: .navigationBar)
      }
    }

    private var pageHeadline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Define your\nfinancial horizon")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.incText)
                .kerning(-1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24)
            Text("Enter your earnings and deductions to project your take-home pay.")
                .font(.system(size: 14))
                .foregroundColor(.incTextDim)
                .lineSpacing(3)
                .frame(maxWidth: 280, alignment: .leading)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    private func loadStatesFromApi() async {
        do {
            state.statesList = try await service.fetchUSStates()
        } catch {
            state.statesList = fallbackStates
        }
    }

    private func triggerCalculation() {
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
