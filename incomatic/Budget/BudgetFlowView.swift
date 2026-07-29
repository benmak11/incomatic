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
                GoalsEntryView(goals: $goals, onContinue: { step = .expenses })
            case .expenses:
                ExpenseEditorView(
                    expenses: $expenses,
                    payFrequency: calculatorState.payFrequency,
                    onContinue: { step = .generating }
                )
            case .generating:
                BudgetGeneratingView()
                    .task {
                        if hasConsented {
                            await generate()
                        } else {
                            showingConsent = true
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
