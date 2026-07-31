//
//  GoalsEntryView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  "What are you saving for?" — first screen of the budget setup flow.
//  Goal-type chips open the editor pre-seeded with that type (the design
//  mock's chips are decorative multi-select with no wiring to goal
//  creation — this fills that gap with the obvious "pick a template"
//  interaction). Cards are priority-ordered; reordering itself isn't
//  built (static in the mock too — matches the rest of the RSU/History
//  surfaces' "no drag-to-reorder yet" scope).
//

import SwiftUI

struct GoalsEntryView: View {
    @Binding var goals: [SavingsGoal]
    let onContinue: () -> Void

    @State private var editingGoal: SavingsGoal?
    @State private var seedType: GoalType = .custom
    @State private var showingEditor = false

    private var sortedGoals: [SavingsGoal] {
        goals.sorted { $0.priority < $1.priority }
    }

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(title: "What are you saving for?")

            Text("Pick as many as you'd like, there's no limit on goals.")
                .font(.system(size: 13.5))
                .foregroundColor(.incTextDim)
                .padding(.horizontal, 26)
                .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GoalType.allCases) { type in
                        chip(type)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 12) {
                    if goals.isEmpty {
                        emptyState
                    } else {
                        ForEach(sortedGoals) { goal in
                            GoalCardRow(goal: goal) {
                                editingGoal = goal
                                showingEditor = true
                            }
                        }
                        addAnotherButton
                    }
                }
                .padding(16)
                .padding(.bottom, 100)
            }

            continueBar
        }
        .background(Color.incBg.ignoresSafeArea())
        .sheet(isPresented: $showingEditor) {
            BudgetGoalEditorSheet(
                existing: editingGoal,
                seedType: seedType,
                nextPriority: goals.count + 1,
                onSave: saveGoal
            )
        }
    }

    private func chip(_ type: GoalType) -> some View {
        Button {
            seedType = type
            editingGoal = nil
            showingEditor = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: type.icon).font(.system(size: 12, weight: .semibold))
                Text(type.displayName).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.incSageDeep)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.incSurface))
            .overlay(Capsule().strokeBorder(Color.incHairlineStrong, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Add your first goal")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundColor(.incText)
            Text("Tap a category above, then set an amount. We'll fold it into your paycheck plan.")
                .font(.system(size: 13.5))
                .foregroundColor(.incTextDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button {
                seedType = .custom
                editingGoal = nil
                showingEditor = true
            } label: {
                Text("Add a goal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSage))
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 30)
    }

    private var addAnotherButton: some View {
        Button {
            seedType = .custom
            editingGoal = nil
            showingEditor = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                Text("Add another goal").font(.system(size: 13.5, weight: .bold))
            }
            .foregroundColor(.incSageDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.incSageSoft, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSageBg))
        }
        .buttonStyle(.plain)
    }

    private var continueBar: some View {
        Button(action: onContinue) {
            Text("Continue")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14).fill(goals.isEmpty ? Color.incDisabled : Color.incBtnSolid))
        }
        .disabled(goals.isEmpty)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .background(Color.incBg.opacity(0.94))
    }

    private func saveGoal(_ goal: SavingsGoal) {
        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[idx] = goal
        } else {
            goals.append(goal)
        }
    }
}

private struct GoalCardRow: View {
    let goal: SavingsGoal
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.incSageBg)
                    Image(systemName: goal.type.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.incSage)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(goal.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.incText)
                        Spacer()
                        Text("PRIORITY \(goal.priority)")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.incTextMute)
                            .kerning(0.5)
                    }
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(.incTextDim)
                }
            }
            .padding(16)
            .background(Color.incSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.incCardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        var text = "\(formatWholeCurrency(goal.currentSaved)) of \(formatWholeCurrency(goal.targetAmount))"
        if let dateString = goal.targetDate, let date = VestMath.parseDate(dateString) {
            text += " · by \(date.formatted(.dateTime.month(.abbreviated).year()))"
        }
        return text
    }
}
