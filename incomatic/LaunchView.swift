//
//  LaunchView.swift
//  incomatic
//
//  Created by Ben Makusha on 5/28/26.
//

import SwiftUI

private extension Color {
    static let launchCream = Color(red: 0.961, green: 0.945, blue: 0.918) // #F5F1EA
    static let launchSage  = Color(red: 0.373, green: 0.549, blue: 0.486) // #5F8C7C
    static let launchInk   = Color(red: 0.122, green: 0.165, blue: 0.165) // #1F2A2A
}

struct LaunchView: View {
    /// Set to false by the host once the splash should dismiss.
    @Binding var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // animation state
    @State private var bloom = false
    @State private var markScale: CGFloat = 1.0
    @State private var wordmarkVisible = false
    @State private var markShift: CGFloat = 0      // x-offset to make room for wordmark

    var body: some View {
        ZStack {
            Color.launchCream.ignoresSafeArea()

            // soft warm bloom behind the mark
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.launchSage.opacity(0.16), Color.launchSage.opacity(0.0)],
                        center: .center, startRadius: 8, endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .scaleEffect(bloom ? 1.0 : 0.2)
                .opacity(bloom ? 1 : 0)

            // mark + wordmark
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.launchSage)
                        .frame(width: 84, height: 84)
                        .shadow(color: Color.launchSage.opacity(0.35), radius: 18, x: 0, y: 8)
                    Text("i")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .italic()
                        .foregroundColor(.white)
                        .offset(x: 1, y: 1)
                }
                .scaleEffect(markScale)
                .offset(x: markShift)

                Text("Incomatic")
                    .font(.system(size: 30, weight: .bold))
                    .kerning(-0.6)
                    .foregroundColor(.launchInk)
                    .opacity(wordmarkVisible ? 1 : 0)
                    .offset(x: wordmarkVisible ? 0 : -12)
                    .fixedSize()
                    // keep the pair visually centred: only claim width once visible
                    .frame(width: wordmarkVisible ? nil : 0, alignment: .leading)
                    .clipped()
            }
        }
        .onAppear(perform: run)
    }

    private func run() {
        guard !reduceMotion else {
            // static, gentle fade only
            bloom = true
            wordmarkVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { dismiss() }
            return
        }

        // 1. warm bloom in
        withAnimation(.easeOut(duration: 0.65)) { bloom = true }

        // 2. mark settles with a soft spring
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            markScale = 0.92
            markShift = -4
        }

        // 3. wordmark fades + slides in
        withAnimation(.easeOut(duration: 0.5).delay(0.45)) {
            wordmarkVisible = true
        }

        // 4. hold, then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { dismiss() }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.45)) { isActive = false }
    }
}

// MARK: - Host wrapper
//
// Drop this in place of `ContentView()` inside the WindowGroup, or use
// the updated `IncomaticApp.swift` provided in this handoff.

struct RootView: View {
    @State private var showLaunch = true
    @StateObject private var upgradeGate = UpgradeGate.shared

    var body: some View {
        ZStack {
            ContentView()

            if showLaunch {
                LaunchView(isActive: $showLaunch)
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Above the splash: once the backend has refused this build there
            // is nothing behind here that can work.
            if let requirement = upgradeGate.requirement {
                UpgradeRequiredView(requirement: requirement)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: upgradeGate.requirement)
        // Runs once per launch, behind the splash, so the newest published tax
        // year is cached before the first calculation is built.
        .task { await refreshTaxYear() }
    }
}

struct LaunchView_Previews: PreviewProvider {
    static var previews: some View {
        StatefulPreviewWrapper(true) { LaunchView(isActive: $0) }
    }
}

/// Small helper so the preview can drive the @Binding.
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content
    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }
    var body: some View { content($value) }
}
