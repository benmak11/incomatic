//
//  BudgetGoalEditorSheet.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Add / edit a single savings goal. Nil `existing` = add mode. Reuses
//  CalculatorFields' underlined-field idioms (amountField, styledMenu,
//  bonusDateRow's DatePicker-or-"pick a date" shape) instead of the design
//  mock's raw <input> styling — same translation GrantFormView did for RSU
//  grants.
//

import SwiftUI

struct BudgetGoalEditorSheet: View {
    /// Nil = add mode. Pre-set to seed the type from a tapped chip.
    var existing: SavingsGoal?
    var seedType: GoalType = .custom
    let nextPriority: Int
    let onSave: (SavingsGoal) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var type: GoalType
    @State private var name: String
    @State private var targetText: String
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date

    init(existing: SavingsGoal? = nil, seedType: GoalType = .custom, nextPriority: Int, onSave: @escaping (SavingsGoal) -> Void) {
        self.existing = existing
        self.seedType = seedType
        self.nextPriority = nextPriority
        self.onSave = onSave
        _type = State(initialValue: existing?.type ?? seedType)
        _name = State(initialValue: existing?.name ?? "")
        _targetText = State(initialValue: existing.map { String(format: "%.0f", $0.targetAmount) } ?? "")
        let existingDate = existing?.targetDate.flatMap { VestMath.parseDate($0) }
        _hasTargetDate = State(initialValue: existingDate != nil)
        _targetDate = State(initialValue: existingDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(existing == nil ? "New goal" : "Edit goal")
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .kerning(-0.4)
                .padding(.bottom, 18)

            CalculatorFields.styledMenu(label: type.displayName) {
                ForEach(GoalType.allCases) { candidate in
                    Button {
                        type = candidate
                    } label: {
                        Label(candidate.displayName, systemImage: candidate.icon)
                    }
                }
            }
            .padding(.bottom, 18)

            CalculatorFields.fieldLabel("NAME")
            TextField("e.g. Japan trip", text: $name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.incText)
                .padding(.bottom, 8)
                .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
                .padding(.bottom, 18)

            CalculatorFields.amountField(label: "Target amount", text: $targetText)

            CalculatorFields.toggleRow("Target date", sub: "Optional: used to flag if you're on pace", isOn: $hasTargetDate)
                .padding(.bottom, hasTargetDate ? 8 : 18)

            if hasTargetDate {
                DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(.incSage)
                    .padding(.bottom, 18)
            }

            Button(action: save) {
                Text("Save goal")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(canSave ? Color.incSage : Color.incDisabled))
            }
            .disabled(!canSave)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 28)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.incSurface)
        .keyboardDoneToolbar()
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(targetText) ?? 0) > 0
    }

    private func save() {
        guard let target = Double(targetText) else { return }
        func isoDate(_ date: Date) -> String {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: date)
        }
        let goal = SavingsGoal(
            id: existing?.id ?? UUID().uuidString,
            type: type,
            name: name.trimmingCharacters(in: .whitespaces),
            targetAmount: target,
            targetDate: hasTargetDate ? isoDate(targetDate) : nil,
            priority: existing?.priority ?? nextPriority,
            currentSaved: existing?.currentSaved ?? 0
        )
        onSave(goal)
        dismiss()
    }
}
