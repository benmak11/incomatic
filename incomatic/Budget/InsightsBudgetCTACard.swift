//
//  InsightsBudgetCTACard.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Entry point into the budget flow from the Insights results screen —
//  placed below the Supplemental/Yearly-outlook cards per the locked
//  design. Copy switches once a budget already exists (returning users
//  skip straight to BudgetShell rather than re-running setup).
//

import SwiftUI

struct InsightsBudgetCTACard: View {
    let hasExistingBudget: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hasExistingBudget ? "Your budget" : "Turn this into a plan")
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .kerning(-0.4)

            Text(hasExistingBudget
                 ? "See how this paycheck fits your goals and expenses."
                 : "Add your expenses and savings goals. We'll build a paycheck-by-paycheck budget.")
                .font(.system(size: 13.5))
                .foregroundColor(.incTextDim)
                .lineSpacing(3)
                .padding(.bottom, 8)

            Button(action: onStart) {
                Text(hasExistingBudget ? "View my budget" : "Build my budget")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSage))
                    .shadow(color: Color.incSage.opacity(0.3), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.incSageBg))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.incSageSoft, lineWidth: 1))
    }
}
