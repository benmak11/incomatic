//
//
//  InsightsTab.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Router for the Insights screen: loading → result → empty.
//

import SwiftUI

struct InsightsTab: View {
    let result: ViewFriendlyResponse?
    let isLoading: Bool
    let errorMessage: String?
    let onAdjust: () -> Void
    let isSignedIn: Bool
    let onShowAccount: () -> Void
    /// Saved grants for the yearly outlook's future-vest segments.
    var outlookGrants: [RsuGrant] = []
    /// Reports scroll direction so the shell's floating pill nav shrinks the
    /// same way here as it does on Calculator.
    var onScrollDirectionChange: (Bool) -> Void = { _ in }

    @State private var atBottom = false
    @State private var bannerDismissed = false

    // Banner is shown whenever we're at the bottom AND it hasn't been dismissed during
    // this visit. Leaving the bottom re-arms it, so it pops again next time you return.
    private var bannerBinding: Binding<Bool> {
        Binding(
            get: { atBottom && !bannerDismissed },
            set: { shown in if !shown { bannerDismissed = true } }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(.incSage)
                        Text("Calculating…").font(.system(size: 14)).foregroundColor(.incTextDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.incBg.ignoresSafeArea())
                } else if let result = result {
                    EarningsBreakdownView(
                        result: result,
                        onAdjust: onAdjust,
                        outlookGrants: outlookGrants,
                        bottomInset: isSignedIn ? 120 : 160,   // clear the save banner + floating pill nav
                        onAtBottomChange: { value in
                            atBottom = value
                            if !value { bannerDismissed = false }   // re-arm when leaving the bottom
                        },
                        onScrollDirectionChange: onScrollDirectionChange
                    )
                } else {
                    emptyState
                }
            }

            if result != nil, !isSignedIn {
                SaveBanner(isVisible: bannerBinding, onSignIn: onShowAccount)
                    .padding(.bottom, 96)   // clear the floating pill nav — was colliding with it
            }
        }
        // Reset bottom/dismiss tracking for each new calculation.
        .onChange(of: isLoading) { _, loading in
            if loading { atBottom = false; bannerDismissed = false }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.incSageBg).frame(width: 80, height: 80)
                Image(systemName: "chart.bar")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.incSage)
            }
            Text("No results yet")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.incText)
            Text("Run a calculation to see your earnings breakdown.")
                .font(.system(size: 14))
                .foregroundColor(.incTextDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onAdjust) {
                Text("Open Calculator")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSage))
                    .shadow(color: Color.incSage.opacity(0.3), radius: 8, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.incBg.ignoresSafeArea())
    }
}
