//
//  ContentView.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//
//  Root view: two-tab TabView (Calculator + Insights) plus auto-route to
//  Insights when a calculation completes.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = SalaryCalculatorViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CalculatorTab(
                locationManager: locationManager,
                viewModel: viewModel
            )
            .tabItem { Label("Calculator", systemImage: "doc.text") }
            .tag(0)

            InsightsTab(
                result: viewModel.calculationResult,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                onAdjust: { selectedTab = 0 }
            )
            .tabItem { Label("Insights", systemImage: "chart.bar") }
            .tag(1)
        }
        .accentColor(.incSage)
        .onChange(of: viewModel.isLoading) { _, loading in
            if !loading && viewModel.calculationResult != nil {
                selectedTab = 1
            }
        }
    }
}

#Preview {
    ContentView()
}
