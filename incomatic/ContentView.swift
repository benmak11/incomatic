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

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = SalaryCalculatorViewModel()
    @StateObject private var accountManager = AccountManager()
    @StateObject private var historyViewModel = HistoryViewModel()
    @StateObject private var equityStore = EquityStore()
    /// Shared with onboarding so answers collected there are already in
    /// place once the Calculator tab is reachable.
    @State private var calculatorState = CalculatorState()
    @State private var selectedTab: MainTab = .calculator
    @State private var showingAccountSheet = false
    @State private var toastMessage: String?
    @State private var pillNavCompact = false
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
            accountManager.restoreSession()
            if accountManager.isSignedIn {
                await historyViewModel.load()
                await equityStore.load()
            }
        }
        .onChange(of: viewModel.isLoading) { _, loading in
            if !loading && viewModel.calculationResult != nil {
                selectedTab = .insights
                if accountManager.isSignedIn {
                    Task {
                        await historyViewModel.load()
                        showToast("Saved to History")
                    }
                }
            }
        }
        .onChange(of: selectedTab) { _, _ in
            pillNavCompact = false
        }
        .onChange(of: accountManager.isSignedIn) { _, signedIn in
            if signedIn {
                Task {
                    await historyViewModel.load()
                    await equityStore.load()
                }
            } else {
                historyViewModel.clearForSignOut()
                equityStore.clear()
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
                        onScrollDirectionChange: { down in pillNavCompact = down }
                    )
                case .insights:
                    InsightsTab(
                        result: viewModel.calculationResult,
                        isLoading: viewModel.isLoading,
                        errorMessage: viewModel.errorMessage,
                        onAdjust: { selectedTab = .calculator },
                        isSignedIn: accountManager.isSignedIn,
                        onShowAccount: { showingAccountSheet = true },
                        outlookGrants: equityStore.grants
                    )
                case .history:
                    HistoryTab(
                        accountManager: accountManager,
                        viewModel: historyViewModel,
                        onShowAccount: { showingAccountSheet = true }
                    )
                }
            }

            AppPillNav(tab: $selectedTab, compact: pillNavCompact, onExpandTap: { pillNavCompact = false })
        }
        .overlay(alignment: .topTrailing) {
            AccountGlyph(
                signedIn: accountManager.isSignedIn,
                user: accountManager.currentUser,
                action: { showingAccountSheet = true }
            )
            .padding(.top, 8)
            .padding(.trailing, 20)
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
    /// shell mounts immediately (mid-calculation); the isLoading watcher above
    /// routes to Insights once the result lands.
    private func finishOnboarding() {
        hasCompletedOnboarding = true
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
