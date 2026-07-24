//
//  BudgetEngine.swift
//  incomatic
//
//  Created by Ben Makusha on 07/23/2026
//
//  Pure paycheck/goal simulation engine — mirrors VestMath's role for RSU
//  math. This is the deterministic half of "LLM sets strategy, math proves
//  it": BudgetPlanService (backend) suggests a per-period $ rate for each
//  goal; this engine either applies that suggestion (capped by what a
//  paycheck can actually afford) or falls back to its own priority-waterfall
//  default when no AI plan is available, so the budget screens work fully
//  offline / when Vertex AI is down.
//
//  NOT a port of the Claude Design prototype's budget-shared.jsx — that demo
//  hardcodes 26 biweekly periods, a flat 29.65% windfall tax estimate, and
//  fixed 2-goal contribution constants. This engine instead: (a) uses the
//  household's real PayFrequency; (b) takes windfalls as already-net dollars
//  (sourced from CalculateResponse.supplemental / RsuGrant vest dates by the
//  caller, never re-deriving a tax rate — see project_bonus_card_estimate
//  memory for why that pattern was retired); (c) generalizes to N goals via
//  a priority waterfall instead of hand-tuned constants; (d) accepts an
//  optional AI-supplied override map.
//
//  Simplified math is deliberate here, same tradeoff USCalculator's
//  pre-2020 W-4 path made: needs/wants are spread evenly across periods
//  (annual cost / periods-per-year) rather than pinned to due-date windows,
//  since this is a planning simulator, not a ledger.
//

import Foundation

nonisolated enum BudgetEngine {

    struct LineItem: Equatable {
        let name: String
        let amount: Double
    }

    struct Paycheck: Identifiable, Equatable {
        let index: Int
        let payDate: Date
        let windowStart: Date
        var items: [LineItem] = []
        var needs: Double = 0
        var wants: Double = 0
        var windfallLabel: String?
        var windfallNet: Double = 0
        var takeHome: Double = 0
        /// goalId -> $ contributed this period.
        var goalContributions: [String: Double] = [:]
        var savings: Double { goalContributions.values.reduce(0, +) }
        var leftover: Double = 0
        var runningBalance: Double = 0
        var id: Int { index }
    }

    struct GoalProjection: Identifiable, Equatable {
        let goalId: String
        /// Nil only if the goal can never be reached (zero rate, already-negative gap).
        let etaDate: Date?
        let cumulativeAtHorizon: Double
        let reachedWithinHorizon: Bool
        /// Running cumulative saved (starting from currentSaved), one entry per generated period.
        let cumulativeSeries: [Double]
        var id: String { goalId }
    }

    struct YearOutlook: Identifiable, Equatable {
        let year: Int
        let total: Double
        let needs: Double
        let wants: Double
        let goalFunding: Double
        let surplus: Double
        var id: Int { year }
    }

    struct Plan: Equatable {
        let paychecks: [Paycheck]
        let goalProjections: [GoalProjection]
        let warnings: [String]
        let rationale: String?
        let needsPerPeriod: Double
        let wantsPerPeriod: Double
        let savingsPerPeriod: Double
        let years: [YearOutlook]
    }

    /// Builds the full plan: paycheck-by-paycheck timeline, per-goal ETA
    /// projections, warnings, and a 3-year outlook.
    ///
    /// - Parameters:
    ///   - aiContributions: goalId -> suggested $/period from `BudgetPlan.goalContributions`.
    ///     When a goal has no entry (or this is nil, e.g. Vertex AI unavailable), the engine
    ///     falls back to its own default rate for that goal. Either way, a contribution is
    ///     still capped by what the paycheck can actually afford that period — the AI sets
    ///     strategy, the engine proves (and corrects) the math.
    ///   - windfalls: already net-of-tax dollar amounts with a date; see the type doc above.
    @MainActor static func buildPlan(
        budget: Budget,
        payFrequency: PayFrequency,
        netIncomePerPeriod: Double,
        windfalls: [Windfall] = [],
        aiContributions: [String: Double]? = nil,
        rationale: String? = nil,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Plan {
        let periodCount = max(1, Int(payFrequency.periodsPerYear.rounded()))
        let payDates = generatePayDates(count: periodCount, from: today, calendar: calendar)
        let averagePeriodDays = 365.0 / Double(periodCount)

        let needsExpenses = budget.expenses.filter { $0.bucket == .needs }
        let wantsExpenses = budget.expenses.filter { $0.bucket == .wants }
        let needsPerPeriod = perPeriodTotal(needsExpenses, periodsPerYear: payFrequency.periodsPerYear)
        let wantsPerPeriod = perPeriodTotal(wantsExpenses, periodsPerYear: payFrequency.periodsPerYear)
        let sharedItems = (needsExpenses + wantsExpenses).map {
            LineItem(name: $0.name, amount: $0.amount * $0.cadence.occurrencesPerYear / payFrequency.periodsPerYear)
        }

        let windfallsByPeriodIndex = assignWindfalls(windfalls, to: payDates, calendar: calendar)
        let goalsByPriority = budget.goals.sorted { $0.priority < $1.priority }
        let defaultRates = Dictionary(uniqueKeysWithValues: goalsByPriority.map {
            ($0.id, defaultRate(for: $0, today: today, averagePeriodDays: averagePeriodDays, calendar: calendar))
        })

        var cumulativeGiven: [String: Double] = Dictionary(uniqueKeysWithValues: goalsByPriority.map { ($0.id, 0) })
        var paychecks: [Paycheck] = []
        var runningBalance = 0.0

        for (index, payDate) in payDates.enumerated() {
            let windowStart = index == 0 ? today : payDates[index - 1]
            let windfall = windfallsByPeriodIndex[index]
            var paycheck = Paycheck(
                index: index,
                payDate: payDate,
                windowStart: windowStart,
                items: sharedItems,
                needs: needsPerPeriod,
                wants: wantsPerPeriod,
                windfallLabel: windfall?.label,
                windfallNet: windfall?.netAmount ?? 0,
                takeHome: netIncomePerPeriod + (windfall?.netAmount ?? 0)
            )

            var capacity = max(0, paycheck.takeHome - paycheck.needs - paycheck.wants)
            for goal in goalsByPriority {
                let rate = aiContributions?[goal.id] ?? defaultRates[goal.id] ?? 0
                let remainingTarget = max(0, goal.targetAmount - goal.currentSaved - (cumulativeGiven[goal.id] ?? 0))
                let contribution = min(rate, capacity, remainingTarget)
                if contribution > 0 {
                    paycheck.goalContributions[goal.id] = contribution
                    capacity -= contribution
                    cumulativeGiven[goal.id, default: 0] += contribution
                }
            }
            paycheck.leftover = capacity
            runningBalance += paycheck.leftover
            paycheck.runningBalance = runningBalance
            paychecks.append(paycheck)
        }

        let goalProjections = goalsByPriority.map { goal in
            projection(
                for: goal,
                paychecks: paychecks,
                defaultRate: defaultRates[goal.id] ?? 0,
                averagePeriodDays: averagePeriodDays,
                calendar: calendar
            )
        }

        let warnings = (rationaleWarnings(from: goalsByPriority, projections: goalProjections, calendar: calendar))

        let years = yearOutlook(
            goals: goalsByPriority,
            paychecks: paychecks,
            needsPerPeriod: needsPerPeriod,
            wantsPerPeriod: wantsPerPeriod,
            netIncomePerPeriod: netIncomePerPeriod,
            periodsPerYear: payFrequency.periodsPerYear,
            startYear: calendar.component(.year, from: today)
        )

        return Plan(
            paychecks: paychecks,
            goalProjections: goalProjections,
            warnings: warnings,
            rationale: rationale,
            needsPerPeriod: needsPerPeriod,
            wantsPerPeriod: wantsPerPeriod,
            savingsPerPeriod: paychecks.isEmpty ? 0 : paychecks.map(\.savings).reduce(0, +) / Double(paychecks.count),
            years: years
        )
    }

    // MARK: - Pay dates

    private static func generatePayDates(count: Int, from today: Date, calendar: Calendar) -> [Date] {
        let step = 365.0 / Double(count)
        return (1...count).map { i in
            calendar.date(byAdding: .day, value: Int((step * Double(i)).rounded()), to: today) ?? today
        }
    }

    // MARK: - Expenses

    private static func perPeriodTotal(_ expenses: [Expense], periodsPerYear: Double) -> Double {
        expenses.reduce(0) { $0 + $1.amount * $1.cadence.occurrencesPerYear / periodsPerYear }
    }

    // MARK: - Windfalls

    private static func assignWindfalls(
        _ windfalls: [Windfall],
        to payDates: [Date],
        calendar: Calendar
    ) -> [Int: Windfall] {
        var byIndex: [Int: Windfall] = [:]
        for windfall in windfalls {
            guard let date = VestMath.parseDate(windfall.date, calendar: calendar) else { continue }
            guard let nearestIndex = payDates.indices.min(by: {
                abs(payDates[$0].timeIntervalSince(date)) < abs(payDates[$1].timeIntervalSince(date))
            }) else { continue }
            byIndex[nearestIndex] = windfall
        }
        return byIndex
    }

    // MARK: - Goal default rate + projection

    private static func defaultRate(
        for goal: SavingsGoal,
        today: Date,
        averagePeriodDays: Double,
        calendar: Calendar
    ) -> Double {
        let remaining = max(0, goal.targetAmount - goal.currentSaved)
        guard remaining > 0 else { return 0 }
        let periodsAvailable: Double
        if let targetDate = goal.targetDate, let target = VestMath.parseDate(targetDate, calendar: calendar) {
            let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
            periodsAvailable = max(1, Double(days) / averagePeriodDays)
        } else {
            periodsAvailable = max(1, 365.0 / averagePeriodDays)
        }
        return remaining / periodsAvailable
    }

    private static func projection(
        for goal: SavingsGoal,
        paychecks: [Paycheck],
        defaultRate: Double,
        averagePeriodDays: Double,
        calendar: Calendar
    ) -> GoalProjection {
        var cumulative = goal.currentSaved
        var series: [Double] = []
        var etaDate: Date?
        for paycheck in paychecks {
            cumulative += paycheck.goalContributions[goal.id] ?? 0
            series.append(cumulative)
            if etaDate == nil, cumulative >= goal.targetAmount {
                etaDate = paycheck.payDate
            }
        }
        let reachedWithinHorizon = etaDate != nil

        if etaDate == nil, defaultRate > 0, let lastDate = paychecks.last?.payDate {
            var extraPeriods = 0
            var projected = cumulative
            while projected < goal.targetAmount && extraPeriods < 10_000 {
                projected += defaultRate
                extraPeriods += 1
            }
            etaDate = calendar.date(byAdding: .day, value: Int((averagePeriodDays * Double(extraPeriods)).rounded()), to: lastDate)
        }

        return GoalProjection(
            goalId: goal.id,
            etaDate: etaDate,
            cumulativeAtHorizon: cumulative,
            reachedWithinHorizon: reachedWithinHorizon,
            cumulativeSeries: series
        )
    }

    private static func rationaleWarnings(
        from goals: [SavingsGoal],
        projections: [GoalProjection],
        calendar: Calendar
    ) -> [String] {
        var warnings: [String] = []
        let projectionsById = Dictionary(uniqueKeysWithValues: projections.map { ($0.goalId, $0) })
        for goal in goals {
            guard let targetDateString = goal.targetDate,
                  let targetDate = VestMath.parseDate(targetDateString, calendar: calendar),
                  let projection = projectionsById[goal.id],
                  let etaDate = projection.etaDate,
                  etaDate > targetDate else { continue }
            let days = calendar.dateComponents([.day], from: targetDate, to: etaDate).day ?? 0
            let months = max(1, Int((Double(days) / 30.0).rounded()))
            warnings.append("\(goal.name) is ~\(months) month\(months == 1 ? "" : "s") behind its date at this rate.")
        }
        return warnings
    }

    // MARK: - Multi-year outlook

    /// Replays the per-period contribution pattern generated for the current
    /// year across `horizonYears`, redirecting a goal's share to surplus once
    /// it's met. Windfalls are only ever in year 1 (they're dated, near-term
    /// entries — nothing recurs in years 2+).
    private static func yearOutlook(
        goals: [SavingsGoal],
        paychecks: [Paycheck],
        needsPerPeriod: Double,
        wantsPerPeriod: Double,
        netIncomePerPeriod: Double,
        periodsPerYear: Double,
        startYear: Int,
        horizonYears: Int = 3
    ) -> [YearOutlook] {
        guard !paychecks.isEmpty else { return [] }
        var cumulativeGiven: [String: Double] = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, 0) })
        var years: [YearOutlook] = []

        for yearOffset in 0..<horizonYears {
            var goalFunding = 0.0
            var redirected = 0.0
            let windfallTotal = yearOffset == 0 ? paychecks.reduce(0) { $0 + $1.windfallNet } : 0
            let annualTotal = netIncomePerPeriod * periodsPerYear + windfallTotal
            let annualNeeds = needsPerPeriod * periodsPerYear
            let annualWants = wantsPerPeriod * periodsPerYear

            for paycheck in paychecks {
                for goal in goals {
                    let plannedRate = paycheck.goalContributions[goal.id] ?? 0
                    guard plannedRate > 0 else { continue }
                    let alreadyGiven = cumulativeGiven[goal.id] ?? 0
                    let remainingTarget = max(0, goal.targetAmount - goal.currentSaved - alreadyGiven)
                    let given = min(plannedRate, remainingTarget)
                    cumulativeGiven[goal.id, default: 0] += given
                    goalFunding += given
                    redirected += plannedRate - given
                }
            }

            let surplus = annualTotal - annualNeeds - annualWants - goalFunding + redirected
            years.append(YearOutlook(
                year: startYear + yearOffset,
                total: annualTotal,
                needs: annualNeeds,
                wants: annualWants,
                goalFunding: goalFunding,
                surplus: surplus
            ))
        }
        return years
    }
}
