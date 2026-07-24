//
//  BudgetAddExpenseSheet.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Add / edit a single itemized expense.
//

import SwiftUI

struct BudgetAddExpenseSheet: View {
    var existing: Expense?
    let onSave: (Expense) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var amountText: String
    @State private var cadence: ExpenseCadence
    @State private var bucket: BudgetBucket
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(existing: Expense? = nil, onSave: @escaping (Expense) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _amountText = State(initialValue: existing.map { String(format: "%.0f", $0.amount) } ?? "")
        _cadence = State(initialValue: existing?.cadence ?? .monthly)
        _bucket = State(initialValue: existing?.bucket ?? .needs)
        let existingDate = existing?.dueDate.flatMap { VestMath.parseDate($0) }
        _hasDueDate = State(initialValue: existingDate != nil)
        _dueDate = State(initialValue: existingDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(existing == nil ? "Add expense" : "Edit expense")
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .kerning(-0.4)
                .padding(.bottom, 18)

            CalculatorFields.fieldLabel("NAME")
            TextField("e.g. Internet", text: $name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.incText)
                .padding(.bottom, 8)
                .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
                .padding(.bottom, 18)

            CalculatorFields.amountField(label: "Amount", text: $amountText)

            CalculatorFields.fieldLabel("CADENCE")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExpenseCadence.allCases) { c in
                        cadenceChip(c)
                    }
                }
            }
            .padding(.bottom, 18)

            CalculatorFields.fieldLabel("BUCKET")
            HStack(spacing: 8) {
                ForEach(BudgetBucket.allCases) { b in
                    bucketChip(b)
                }
            }
            .padding(.bottom, 18)

            CalculatorFields.toggleRow("Due date", sub: "Optional", isOn: $hasDueDate)
                .padding(.bottom, hasDueDate ? 8 : 18)

            if hasDueDate {
                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(.incSage)
                    .padding(.bottom, 18)
            }

            Button(action: save) {
                Text("Save expense")
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

    private func cadenceChip(_ c: ExpenseCadence) -> some View {
        Button { cadence = c } label: {
            Text(c.displayName)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(cadence == c ? .white : .incText)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Capsule().fill(cadence == c ? Color.incSage : Color.clear))
                .overlay(Capsule().strokeBorder(cadence == c ? Color.clear : Color.incHairlineStrong, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func bucketChip(_ b: BudgetBucket) -> some View {
        Button { bucket = b } label: {
            Text(b.displayName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(bucket == b ? .white : .incText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(bucket == b ? b.color : Color.incBg))
        }
        .buttonStyle(.plain)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(amountText) ?? 0) > 0
    }

    private func save() {
        guard let amount = Double(amountText) else { return }
        func isoDate(_ date: Date) -> String {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: date)
        }
        let expense = Expense(
            id: existing?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            cadence: cadence,
            bucket: bucket,
            dueDate: hasDueDate ? isoDate(dueDate) : nil,
            category: existing?.category
        )
        onSave(expense)
        dismiss()
    }
}
