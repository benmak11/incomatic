//
//  BudgetConsentSheet.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Blocking data-consent gate shown before the first AI plan generation —
//  mirrors AccountSheet's rounded-bottom-sheet shape. Persisted via
//  @AppStorage so it's only shown once per device; VertexGenerativeAiClient
//  runs server-side only (see CLAUDE.md), this sheet is the disclosure that
//  the household's financial inputs are sent there to build the plan.
//

import SwiftUI

struct BudgetConsentSheet: View {
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.incSageBg)
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.incSage)
            }
            .frame(width: 52, height: 52)
            .padding(.bottom, 18)

            Text("Building your plan takes a little help")
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .kerning(-0.4)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text("To put together a paycheck-by-paycheck plan, we send your financial inputs (including the amounts you've typed in) to Google's AI. Nothing is shared beyond generating this plan.")
                .font(.system(size: 13.5))
                .foregroundColor(.incTextDim)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.bottom, 26)

            Button(action: onAllow) {
                Text("Allow")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSage))
                    .shadow(color: Color.incSage.opacity(0.3), radius: 8, x: 0, y: 2)
            }

            Button(action: onNotNow) {
                Text("Not now")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.incTextDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 28)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.incSurface)
    }
}
