//
//  ExpenseEditorView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  "Your expenses" — 50/30/20-style donut header + bucket-grouped rows.
//  Second screen of the budget setup flow, and reused (read-mostly) inside
//  BudgetShell's Overview tab via BudgetBucketDonut.
//

import SwiftUI

struct BudgetBucketDonut: View {
    let needs: Double
    let wants: Double
    let savings: Double

    private var total: Double { needs + wants + savings }

    var body: some View {
        VStack(spacing: 16) {
            DonutChart(
                wedges: [
                    .init(value: needs, color: .incSageDeep),
                    .init(value: wants, color: .incBlush),
                    .init(value: savings, color: .incGold),
                ],
                centerLabel: "Per paycheck",
                centerValue: formatWholeCurrency(total),
                thickness: 20
            )
            .frame(width: 168, height: 168)

            HStack(spacing: 18) {
                legendDot("Needs", needs, .incSageDeep)
                legendDot("Wants", wants, .incBlush)
                legendDot("Savings", savings, .incGold)
            }
        }
    }

    private func legendDot(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text("\(label) · \(formatWholeCurrency(value))")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.incTextDim)
        }
    }
}

struct ExpenseEditorView: View {
    @Binding var expenses: [Expense]
    let payFrequency: PayFrequency
    let onContinue: () -> Void

    @State private var editingExpense: Expense?
    @State private var showingEditor = false

    private var needsPerPeriod: Double { total(for: .needs) }
    private var wantsPerPeriod: Double { total(for: .wants) }
    private var savingsPerPeriod: Double { total(for: .savings) }

    private func total(for bucket: BudgetBucket) -> Double {
        expenses.filter { $0.bucket == bucket }
            .reduce(0) { $0 + $1.amount * $1.cadence.occurrencesPerYear / payFrequency.periodsPerYear }
    }

    var body: some View {
        VStack(spacing: 0) {
            AppSectionHeader(title: "Your expenses")

            ScrollView {
                VStack(spacing: 14) {
                    IncCard {
                        BudgetBucketDonut(needs: needsPerPeriod, wants: wantsPerPeriod, savings: savingsPerPeriod)
                            .frame(maxWidth: .infinity)
                    }

                    group("Needs", color: .incSageDeep, bucket: .needs)
                    group("Wants", color: .incBlush, bucket: .wants)
                    group("Savings", color: .incGold, bucket: .savings)

                    addButton
                }
                .padding(16)
                .padding(.bottom, 100)
            }

            continueBar
        }
        .background(Color.incBg.ignoresSafeArea())
        .sheet(isPresented: $showingEditor) {
            BudgetAddExpenseSheet(existing: editingExpense, onSave: saveExpense)
        }
    }

    @ViewBuilder
    private func group(_ title: String, color: Color, bucket: BudgetBucket) -> some View {
        let rows = expenses.filter { $0.bucket == bucket }
        if !rows.isEmpty {
            IncCard {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(title.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.incTextMute)
                            .kerning(0.7)
                    }
                    .padding(.bottom, 4)

                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, expense in
                        Button {
                            editingExpense = expense
                            showingEditor = true
                        } label: {
                            expenseRow(expense)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) {
                            if idx > 0 { Rectangle().fill(Color.incHairline).frame(height: 1) }
                        }
                    }
                }
            }
        }
    }

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(.incText)
                Text(expense.cadence.displayName)
                    .font(.system(size: 11.5))
                    .foregroundColor(.incTextMute)
            }
            Spacer()
            Text(formatWholeCurrency(expense.amount))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.incText)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }

    private var addButton: some View {
        Button {
            editingExpense = nil
            showingEditor = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                Text("Add an expense").font(.system(size: 13.5, weight: .bold))
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
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.incBtnSolid))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .background(Color.incBg.opacity(0.94))
    }

    private func saveExpense(_ expense: Expense) {
        if let idx = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[idx] = expense
        } else {
            expenses.append(expense)
        }
    }
}
