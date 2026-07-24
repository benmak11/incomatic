//
//  BudgetGeneratingView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//

import SwiftUI

struct BudgetGeneratingView: View {
    var body: some View {
        VStack(spacing: 22) {
            ProgressView()
                .controlSize(.large)
                .tint(.incSage)

            Text("Building your plan…")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundColor(.incText)

            Text("Fitting your expenses and goals around every paycheck.")
                .font(.system(size: 13.5))
                .foregroundColor(.incTextDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.incBg.ignoresSafeArea())
    }
}
