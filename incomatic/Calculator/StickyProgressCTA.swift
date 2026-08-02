//
//  
//  StickyProgressCTA.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Button row for the Calculator tab's bottom dock. On non-final sections
//  the primary button advances to next; on the final section it flips to
//  "Calculate detailed projection". The live projection number that used
//  to live in this view's own ribbon now lives in the sticky
//  AppSectionHeader instead (see CalculatorBottomDock.swift).
//

import SwiftUI

struct StickyProgressCTA: View {
    @Binding var activeSection: CalculatorSection
    let isLoading: Bool
    let canCalculate: Bool
    let onCalculate: () -> Void

    private var idx: Int { CalculatorSection.allCases.firstIndex(of: activeSection) ?? 0 }
    private var isLast: Bool { idx == CalculatorSection.allCases.count - 1 }
    private var nextSection: CalculatorSection? {
        let all = CalculatorSection.allCases
        return idx + 1 < all.count ? all[idx + 1] : nil
    }

    var body: some View {
        buttonRow
        .background(Color.incSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22).strokeBorder(Color.incHairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 24, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 14)
    }

    private var buttonRow: some View {
        HStack(spacing: 8) {
            if !isLast {
                Button(action: onCalculate) {
                    Text("Skip to calc")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(canCalculate ? .incSage : .incTextMute)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(canCalculate ? Color.incSageSoft : Color.incHairline, lineWidth: 1.5)
                        )
                }
                .disabled(!canCalculate || isLoading)
            }

            Button(action: {
                if isLast { onCalculate() }
                else if let next = nextSection {
                    withAnimation(.easeInOut(duration: 0.35)) { activeSection = next }
                }
            }) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.white)
                        Text("Calculating…")
                    } else {
                        Text(isLast
                             ? "Calculate detailed projection"
                             : "Continue to \(nextSection?.displayName ?? "")")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .kerning(-0.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isLast && !canCalculate ? Color.incDisabled : Color.incSage)
                )
                .shadow(
                    color: (isLast && !canCalculate) ? .clear : Color.incSage.opacity(0.3),
                    radius: 8, x: 0, y: 2
                )
            }
            .disabled((isLast && !canCalculate) || isLoading)
        }
        .padding(10)
    }
}
