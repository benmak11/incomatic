//
//  CalculatorBottomDock.swift
//  incomatic
//
//  Bottom chrome for the Calculator tab: the recalc nudge, the CTA button
//  row, and the tab-switcher pill, stacked as one unit and attached via
//  .safeAreaInset(edge: .bottom) on CalculatorTab's ScrollView. Previously
//  these were two independently-floating overlays (a separately-positioned
//  StickyProgressCTA and the shell's own AppPillNav) tuned with unrelated
//  hardcoded offsets, which could overlap scroll content that ran past
//  either one's guessed clearance. Composing them together here — and
//  letting safeAreaInset auto-reserve exactly the space this view actually
//  needs — removes that whole class of bug.
//

import SwiftUI

struct CalculatorBottomDock: View {
    @Binding var activeSection: CalculatorSection
    @Binding var tab: MainTab
    let isLoading: Bool
    let canCalculate: Bool
    let needsRecalculation: Bool
    let onCalculate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if needsRecalculation && canCalculate {
                recalcNudge
            }
            StickyProgressCTA(
                activeSection: $activeSection,
                isLoading: isLoading,
                canCalculate: canCalculate,
                onCalculate: onCalculate
            )
            AppPillNav(tab: $tab)
        }
    }

    private var recalcNudge: some View {
        Button(action: onCalculate) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .bold))
                Text("Inputs changed, recalculate to update your results")
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
}
