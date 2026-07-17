//
//  GrantDetailView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  Grant detail (§E): facts + full vest timeline + Edit (pre-filled form)
//  + Delete (destructive, confirmed).
//

import SwiftUI

struct GrantDetailView: View {
    @ObservedObject var store: EquityStore
    let grant: RsuGrant
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    /// Live copy — the store's version reflects edits saved from the form.
    private var current: RsuGrant {
        store.grants.first { $0.id == grant.id } ?? grant
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                factsCard
                timelineCard
                deleteButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.incBg.ignoresSafeArea())
        .navigationTitle(current.ticker ?? current.company ?? "Grant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GrantFormView(store: store, existing: current, onSaved: onChanged)
                } label: {
                    Text("Edit")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.incSage)
                }
            }
        }
        .confirmationDialog(
            "Delete this grant?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete grant", role: .destructive) {
                Task {
                    await store.delete(current)
                    onChanged()
                    dismiss()
                }
            }
        } message: {
            Text("Its vesting value is removed from this year's calculation.")
        }
    }

    private var factsCard: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                CalculatorFields.cardHeader(
                    icon: "doc.text",
                    title: current.company ?? current.ticker ?? "Grant",
                    sub: current.manualPrice == true ? "Manual price" : current.ticker
                )
                factRow("Total shares", value: "\(formatShares(current.sharesTotal))")
                factRow("Price per share", value: formatCurrency(current.pricePerShare))
                factRow("Grant value", value: formatWholeCurrency(current.sharesTotal * current.pricePerShare))
                factRow("Grant date", value: current.grantDate)
                factRow("Schedule", value: current.schedule.label)
            }
        }
    }

    private func factRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(.incTextDim)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.incText)
                .monospacedDigit()
        }
        .padding(.vertical, 5)
    }

    private var timelineCard: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                CalculatorFields.cardHeader(icon: "chart.bar.doc.horizontal", title: "Vest distribution")
                VestTimelineView(grant: current)
            }
        }
    }

    private var deleteButton: some View {
        Button {
            confirmDelete = true
        } label: {
            Text("Delete grant")
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.incRed)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.incRed.opacity(0.4), lineWidth: 1.5))
        }
    }
}
