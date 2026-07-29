//
//  BudgetShell.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Landing surface once a plan exists: Overview/Paychecks/Goals/Outlook
//  sub-tabs under their own serif header — NOT a 4th bottom pill (per the
//  locked design). Back returns to Insights, wired by the presenting flow.
//

import SwiftUI

private enum BudgetTab: Int, CaseIterable {
    case overview, paychecks, goals, outlook
    var label: String {
        switch self {
        case .overview:  return "Overview"
        case .paychecks: return "Paychecks"
        case .goals:     return "Goals"
        case .outlook:   return "Outlook"
        }
    }
}

/// Serif "Budget" title + hairline sub-tabs — sibling to AppSectionHeader,
/// not a reuse of it, since AppSectionHeader's `section` binding is typed
/// to CalculatorSection specifically.
private struct BudgetSectionHeader: View {
    @Binding var tab: BudgetTab
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.incTextDim)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.incSurface))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.bottom, 10)

            Text("Budget")
                .font(.system(size: 34, weight: .medium, design: .serif))
                .foregroundColor(.incText).kerning(-1)
                .padding(.bottom, 18)

            HStack(spacing: 20) {
                ForEach(BudgetTab.allCases, id: \.self) { t in
                    let active = t == tab
                    Button { tab = t } label: {
                        VStack(spacing: 10) {
                            Text(t.label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(active ? .incText : .incTextMute)
                            Rectangle().fill(active ? Color.incSage : Color.clear).frame(height: 2)
                        }.fixedSize()
                    }.buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.incHairline).frame(height: 1) }
        }
        .padding(.top, 12).padding(.horizontal, 26).padding(.bottom, 20)
    }
}

struct BudgetShell: View {
    let plan: BudgetEngine.Plan
    let goals: [SavingsGoal]
    let onBack: () -> Void

    @State private var tab: BudgetTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            BudgetSectionHeader(tab: $tab, onBack: onBack)

            Group {
                switch tab {
                case .overview:
                    BudgetOverviewTab(plan: plan, goals: goals)
                case .paychecks:
                    PaycheckTimelineView(paychecks: plan.paychecks, todayIndex: 0)
                case .goals:
                    GoalProgressView(goals: goals, projections: plan.goalProjections)
                case .outlook:
                    BudgetOutlookView(years: plan.years)
                }
            }
        }
        .background(Color.incBg.ignoresSafeArea())
    }
}

private struct BudgetOverviewTab: View {
    let plan: BudgetEngine.Plan
    let goals: [SavingsGoal]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                IncCard {
                    BudgetBucketDonut(needs: plan.needsPerPeriod, wants: plan.wantsPerPeriod, savings: plan.savingsPerPeriod)
                        .frame(maxWidth: .infinity)
                }

                if let rationale = plan.rationale {
                    IncCard {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.incSageBg)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.incSage)
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("How I built this")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.incText)
                                Text(rationale)
                                    .font(.system(size: 13))
                                    .foregroundColor(.incTextDim)
                                    .lineSpacing(3)
                            }
                        }
                    }
                }

                if let warning = plan.warnings.first {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.incBlush)
                        Text(warning)
                            .font(.system(size: 12.5))
                            .foregroundColor(.incText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.incBlushBg))
                }

                IncCard {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("GOALS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.incTextMute)
                            .kerning(0.7)
                            .padding(.bottom, 10)

                        ForEach(Array(goals.sorted { $0.priority < $1.priority }.enumerated()), id: \.element.id) { idx, goal in
                            let projection = plan.goalProjections.first { $0.goalId == goal.id }
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(Color.incSageBg)
                                    Image(systemName: goal.type.icon)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.incSage)
                                }
                                .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(goal.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.incText)
                                    if let projection, goal.targetAmount > 0 {
                                        Text("\(Int((min(1, projection.cumulativeAtHorizon / goal.targetAmount)) * 100))% funded")
                                            .font(.system(size: 12))
                                            .foregroundColor(.incTextMute)
                                    }
                                }
                                Spacer()
                                if let projection {
                                    Text(formatWholeCurrency(projection.cumulativeAtHorizon))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.incSageDeep)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.vertical, 8)
                            .overlay(alignment: .top) {
                                if idx > 0 { Rectangle().fill(Color.incHairline).frame(height: 1) }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }
}
