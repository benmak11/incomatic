//
//  BudgetEngineTests.swift
//  incomaticTests
//
//  Created by Ben Makusha on 07/23/2026
//
//  Not yet runnable — no Unit Testing Bundle target exists in the Xcode
//  project yet (File → New → Target → Unit Testing Bundle, add this file to
//  it). incomatic/ itself is a synchronized file-system group, so app-target
//  sources are already visible via @testable import once the target exists.
//

import XCTest
@testable import Incomatic

@MainActor
final class BudgetEngineTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ iso: String) -> Date {
        VestMath.parseDate(iso, calendar: calendar)!
    }

    func test_priorityWaterfall_fundsHigherPriorityGoalFirst() {
        let high = SavingsGoal(type: .emergencyFund, name: "Emergency", targetAmount: 10_000, priority: 1)
        let low = SavingsGoal(type: .vacation, name: "Vacation", targetAmount: 10_000, priority: 2)
        let budget = Budget(goals: [low, high], expenses: [])

        let plan = BudgetEngine.buildPlan(
            budget: budget,
            payFrequency: .biweekly,
            netIncomePerPeriod: 100,
            today: date("2026-01-01"),
            calendar: calendar
        )

        // Every period's full $100 capacity should go to the priority-1 goal
        // until it's satisfied; the lower-priority goal gets nothing yet.
        let firstPeriod = plan.paychecks.first!
        XCTAssertEqual(firstPeriod.goalContributions[high.id] ?? 0, 100, accuracy: 0.01)
        XCTAssertNil(firstPeriod.goalContributions[low.id])
    }

    func test_aiOverride_isCappedByAvailablePaycheckCapacity() {
        let goal = SavingsGoal(type: .emergencyFund, name: "Emergency", targetAmount: 50_000, priority: 1)
        let expense = Expense(name: "Rent", amount: 1_800, cadence: .monthly, bucket: .needs)
        let budget = Budget(goals: [goal], expenses: [expense])

        // AI suggests $5,000/period — nowhere near affordable on a $2,000 net paycheck.
        let plan = BudgetEngine.buildPlan(
            budget: budget,
            payFrequency: .monthly,
            netIncomePerPeriod: 2_000,
            aiContributions: [goal.id: 5_000],
            today: date("2026-01-01"),
            calendar: calendar
        )

        let firstPeriod = plan.paychecks.first!
        // Capacity = $2,000 net - $1,800 rent = $200, regardless of the AI's $5,000 suggestion.
        XCTAssertEqual(firstPeriod.goalContributions[goal.id] ?? 0, 200, accuracy: 0.01,
                        "capped by needs-adjusted capacity, not the AI's raw suggestion")
    }

    func test_windfall_isAppliedNetWithoutAdditionalTaxDerivation() {
        let goal = SavingsGoal(type: .emergencyFund, name: "Emergency", targetAmount: 100_000, priority: 1)
        let budget = Budget(goals: [goal], expenses: [])
        let windfall = Windfall(label: "March bonus", netAmount: 7_035, date: "2026-03-15")

        let plan = BudgetEngine.buildPlan(
            budget: budget,
            payFrequency: .biweekly,
            netIncomePerPeriod: 2_000,
            windfalls: [windfall],
            today: date("2026-01-01"),
            calendar: calendar
        )

        let windfallPeriod = plan.paychecks.first { $0.windfallLabel == "March bonus" }
        XCTAssertNotNil(windfallPeriod)
        XCTAssertEqual(windfallPeriod?.windfallNet ?? 0, 7_035, accuracy: 0.01)
        XCTAssertEqual(windfallPeriod?.takeHome ?? 0, 2_000 + 7_035, accuracy: 0.01)
    }

    func test_datedGoal_behindScheduleProducesWarning() {
        // $1/period toward a $10,000 goal due in 30 days can't possibly be met.
        let goal = SavingsGoal(
            type: .vacation, name: "Japan trip", targetAmount: 10_000,
            targetDate: "2026-01-31", priority: 1, currentSaved: 0
        )
        let budget = Budget(goals: [goal], expenses: [])

        let plan = BudgetEngine.buildPlan(
            budget: budget,
            payFrequency: .monthly,
            netIncomePerPeriod: 1,
            today: date("2026-01-01"),
            calendar: calendar
        )

        XCTAssertTrue(plan.warnings.contains { $0.contains("Japan trip") })
    }

    func test_goalMetEarly_stopsAccumulatingBeyondTarget() {
        // AI override of $200/period against a $500 goal with no capacity
        // constraint — should stop taking money once the goal is met rather
        // than continuing to skim $200/week for the rest of the horizon.
        let goal = SavingsGoal(type: .emergencyFund, name: "Emergency", targetAmount: 500, priority: 1, currentSaved: 0)
        let budget = Budget(goals: [goal], expenses: [])

        let plan = BudgetEngine.buildPlan(
            budget: budget,
            payFrequency: .weekly,
            netIncomePerPeriod: 1_000,
            aiContributions: [goal.id: 200],
            today: date("2026-01-01"),
            calendar: calendar
        )

        let projection = plan.goalProjections.first { $0.goalId == goal.id }!
        XCTAssertTrue(projection.reachedWithinHorizon)
        XCTAssertEqual(projection.cumulativeAtHorizon, 500, accuracy: 0.01, "capacity beyond the target should flow to leftover, not overshoot the goal")

        let fundedPeriods = plan.paychecks.filter { ($0.goalContributions[goal.id] ?? 0) > 0 }
        XCTAssertEqual(fundedPeriods.count, 3, "200 + 200 + 100 reaches 500 in the third period, then contributions stop")
    }
}
