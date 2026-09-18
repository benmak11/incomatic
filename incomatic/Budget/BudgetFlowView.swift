//
//  BudgetFlowView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Orchestrates the budget setup flow: Goals -> Expenses -> (consent gate,
//  first time only) -> Generating -> Shell. A returning user with an
//  already-saved budget skips straight to Generating (re-running the plan
//  against their current goals/expenses/latest windfalls is more correct
//  than caching a stale one — POST /v1/budget/plan has no persisted
//  counterpart server-side). Consent is checked every time generation
//  actually runs, not just on the first-time path, so there's no way to
//  reach the AI call without having granted it.
//
//  Presented as a fullScreenCover, which has no swipe-to-dismiss and no system
//  back. Every step therefore draws its own way out: only the shell used to,
//  which left anyone on goals or expenses (or dropped back there by "Not now"
//  on the consent sheet) with no way to leave at all.
//

import SwiftUI

struct BudgetFlowView: View {
    @ObservedObject var budgetStore: BudgetStore
    let calculatorState: CalculatorState
    let calculationResult: ViewFriendlyResponse
    let grants: [RsuGrant]
    let onClose: () -> Void

    @AppStorage("incomatic.hasConsentedToBudgetAI") private var hasConsented = false

    private enum Step {
        case goals, expenses, generating, shell
    }

    @State private var step: Step
    @State private var goals: [SavingsGoal]
    @State private var expenses: [Expense]
    @State private var showingConsent = false
    @State private var plan: BudgetEngine.Plan?

    init(
        budgetStore: BudgetStore,
        calculatorState: CalculatorState,
        calculationResult: ViewFriendlyResponse,
        grants: [RsuGrant],
        onClose: @escaping () -> Void
    ) {
        self.budgetStore = budgetStore
        self.calculatorState = calculatorState
        self.calculationResult = calculationResult
        self.grants = grants
        self.onClose = onClose
        let budget = budgetStore.budget
        _goals = State(initialValue: budget.goals)
        _expenses = State(initialValue: budget.expenses)
        _step = State(initialValue: (budget.goals.isEmpty && budget.expenses.isEmpty) ? .goals : .generating)
    }

    var body: some View {
        Group {
            switch step {
            case .goals:
                // Nothing precedes goals, so "back" here leaves the flow. Unsaved
                // edits are discarded; nothing persists until generation runs.
                leaving(label: "Close", action: onClose) {
                    GoalsEntryView(goals: $goals, onContinue: { step = .expenses })
                }
            case .expenses:
                leaving(label: "Back", action: { step = .goals }) {
                    ExpenseEditorView(
                        expenses: $expenses,
                        payFrequency: calculatorState.payFrequency,
                        onContinue: { step = .generating }
                    )
                }
            case .generating:
                // Closing here cancels the in-flight task with the view. The budget
                // itself may already be saved by then, which is fine: the next open
                // starts at generating again rather than losing the goals.
                leaving(label: "Cancel", action: onClose) {
                    BudgetGeneratingView()
                        .task {
                            if hasConsented {
                                await generate()
                            } else {
                                showingConsent = true
                            }
                        }
                }
            case .shell:
                if let plan {
                    BudgetShell(plan: plan, goals: goals, onBack: onClose)
                }
            }
        }
        .sheet(isPresented: $showingConsent) {
            BudgetConsentSheet(
                onAllow: {
                    hasConsented = true
                    showingConsent = false
                    Task { await generate() }
                },
                onNotNow: {
                    showingConsent = false
                    step = goals.isEmpty ? .goals : .expenses
                }
            )
        }
    }

    private func leaving<Content: View>(
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        BudgetStepChrome(label: label, action: action, content: content)
    }

    private func generate() async {
        let budget = Budget(goals: goals, expenses: expenses)
        _ = await budgetStore.save(budget)

        let request = buildBudgetPlanRequest(
            budget: budget,
            state: calculatorState,
            result: calculationResult,
            grants: grants
        )
        let aiPlan = await budgetStore.generatePlan(request)
        let aiContributions: [String: Double]? = aiPlan.map {
            Dictionary(uniqueKeysWithValues: $0.goalContributions.map { ($0.goalId, $0.suggestedPerPeriodAmount) })
        }

        plan = BudgetEngine.buildPlan(
            budget: budget,
            payFrequency: calculatorState.payFrequency,
            netIncomePerPeriod: request.netIncomePerPeriod,
            windfalls: request.windfalls,
            aiContributions: aiContributions,
            rationale: aiPlan?.rationale
        )
        step = .shell
    }
}

/// The way out, drawn above a budget setup step.
///
/// The shell draws its own back control inside its header. The setup steps use
/// `AppSectionHeader`, which has no leading slot, so the control sits above it at the
/// same horizontal inset as the title. A separate view rather than a private helper so
/// the one property that matters - that the exit exists and fires - can be tested
/// without constructing the flow's heavyweight inputs.
struct BudgetStepChrome<Content: View>: View {
    let label: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BudgetBackButton(label: label, action: action)
                Spacer()
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 4)
            content()
        }
    }
}
