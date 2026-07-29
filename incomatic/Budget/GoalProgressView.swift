//
//  GoalProgressView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Per-goal progress ring + on-track/behind badge, sourced from
//  BudgetEngine.GoalProjection. Behind-schedule goals get the blush badge
//  the engine's own `warnings` already flag in plain language elsewhere.
//

import SwiftUI

struct GoalProgressView: View {
    let goals: [SavingsGoal]
    let projections: [BudgetEngine.GoalProjection]

    private func projection(for goal: SavingsGoal) -> BudgetEngine.GoalProjection? {
        projections.first { $0.goalId == goal.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(goals.sorted { $0.priority < $1.priority }) { goal in
                    if let projection = projection(for: goal) {
                        GoalRingCard(goal: goal, projection: projection)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }
}

private struct GoalRingCard: View {
    let goal: SavingsGoal
    let projection: BudgetEngine.GoalProjection

    private var pct: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(100, (projection.cumulativeAtHorizon / goal.targetAmount) * 100)
    }

    private var targetDate: Date? {
        goal.targetDate.flatMap { VestMath.parseDate($0) }
    }

    private var isBehind: Bool {
        guard let targetDate, let eta = projection.etaDate else { return false }
        return eta > targetDate
    }

    var body: some View {
        IncCard {
            HStack(spacing: 16) {
                DonutChart(
                    wedges: [
                        .init(value: pct, color: isBehind ? .incBlush : .incSage),
                        .init(value: max(0, 100 - pct), color: .incHairline),
                    ],
                    centerLabel: "",
                    centerValue: "\(Int(pct.rounded()))%",
                    thickness: 10
                )
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: goal.type.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.incSage)
                        Text(goal.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.incText)
                    }
                    Text("\(formatWholeCurrency(projection.cumulativeAtHorizon)) of \(formatWholeCurrency(goal.targetAmount))")
                        .font(.system(size: 13))
                        .foregroundColor(.incTextDim)

                    if let targetDate {
                        Text(isBehind ? "Behind · by \(targetDate.formatted(.dateTime.month(.abbreviated).year()))"
                                      : "On track · by \(targetDate.formatted(.dateTime.month(.abbreviated).year()))")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(isBehind ? .incBlush : .incSageDeep)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(isBehind ? Color.incBlushBg : Color.incSageBg))
                    } else if let eta = projection.etaDate {
                        Text("ETA ~\(eta.formatted(.dateTime.month(.abbreviated).year()))")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.incSageDeep)
                    }
                }
            }
        }
    }
}
