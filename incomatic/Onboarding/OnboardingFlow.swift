//
//  OnboardingFlow.swift
//  incomatic
//
//  Created by Ben Makusha on 07/21/2026
//
//  Step sequence + navigation for the Guided Notebook onboarding (design §A3).
//  No W-4/dependents step — those fields stay reachable later on the Federal
//  section, just not part of first-run intake.
//

import Observation

enum OnboardingStep: CaseIterable {
    case greet, wage, payFrequency, payday, bonus, commission, filingStatus, state, benefits, retirement, review
}

@Observable
final class OnboardingFlow {
    let steps = OnboardingStep.allCases
    private(set) var stepIndex = 0

    /// Tri-state: nil = unanswered yet. Drives whether the amount field shows
    /// and gates "Continue", mirroring the mock's yes/no-amount step kind.
    var wantsBonus: Bool?
    var wantsCommission: Bool?

    /// The payday anchor collected during intake. Held here rather than on
    /// CalculatorState because it is persisted to a different place: the app
    /// group, so the widget extension can read it.
    var payAnchor: PayAnchor?

    var step: OnboardingStep { steps[stepIndex] }
    var isGreet: Bool { step == .greet }
    var isReview: Bool { step == .review }
    var progress: Double { Double(stepIndex) / Double(steps.count - 1) }

    func next() {
        stepIndex = min(steps.count - 1, stepIndex + 1)
        // Tracked here rather than in the view: this is the single place the flow
        // advances, so no future entry point can skip the funnel event.
        Task { @MainActor in
            Analytics.shared.track(AnalyticsEventName.onboardingStep,
                                   properties: ["step": String(describing: steps[stepIndex])])
        }
    }
    func back() { stepIndex = max(0, stepIndex - 1) }
    func jump(to target: OnboardingStep) {
        if let i = steps.firstIndex(of: target) { stepIndex = i }
    }

    func canProceed(state: CalculatorState) -> Bool {
        switch step {
        case .wage:
            return state.incomeType == .salary
                ? (Double(state.salaryAmount) ?? 0) > 0
                : (Double(state.hourlyRate) ?? 0) > 0
        case .bonus: return wantsBonus != nil
        case .commission: return wantsCommission != nil
        default: return true
        }
    }
}
