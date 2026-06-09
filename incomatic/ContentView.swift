//
//  ContentView.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//
//  Root view: three-tab TabView (Calculator + Insights + History), hosts the
//  AccountManager + AccountSheet, and routes to Insights when a calculation
//  completes.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = SalaryCalculatorViewModel()
    @StateObject private var accountManager = AccountManager()
    @StateObject private var historyViewModel = HistoryViewModel()
    @State private var selectedTab: Int = 0
    @State private var showingAccountSheet = false
    @State private var toastMessage: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            CalculatorTab(
                locationManager: locationManager,
                viewModel: viewModel,
                accountManager: accountManager,
                onShowAccount: { showingAccountSheet = true }
            )
            .tabItem { Label("Calculator", systemImage: "doc.text") }
            .tag(0)

            InsightsTab(
                result: viewModel.calculationResult,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                onAdjust: { selectedTab = 0 },
                isSignedIn: accountManager.isSignedIn,
                onShowAccount: { showingAccountSheet = true }
            )
            .tabItem { Label("Insights", systemImage: "chart.bar") }
            .tag(1)

            HistoryTab(
                accountManager: accountManager,
                viewModel: historyViewModel,
                onShowAccount: { showingAccountSheet = true }
            )
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(2)
        }
        .accentColor(.incSage)
        .overlay(alignment: .bottom) {
            if let toastMessage {
                SavedToast(text: toastMessage)
                    .padding(.bottom, 100)
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
            accountManager.restoreSession()
            if accountManager.isSignedIn { await historyViewModel.load() }
        }
        .onChange(of: viewModel.isLoading) { _, loading in
            if !loading && viewModel.calculationResult != nil {
                selectedTab = 1
                if accountManager.isSignedIn {
                    Task {
                        await historyViewModel.load()
                        showToast("Saved to History")
                    }
                }
            }
        }
        .onChange(of: accountManager.isSignedIn) { _, signedIn in
            if signedIn {
                Task { await historyViewModel.load() }
            } else {
                historyViewModel.clearForSignOut()
            }
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
