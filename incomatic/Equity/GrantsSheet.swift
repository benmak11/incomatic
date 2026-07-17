//
//  GrantsSheet.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  Grants list presented over the Calculator tab (§B): rows with ticker,
//  schedule label, value vesting this year, and next vest date. Swipe to
//  delete (optimistic, §G), tap for detail, "+ Add grant" primary action.
//

import SwiftUI

struct GrantsSheet: View {
    @ObservedObject var store: EquityStore
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.grants.isEmpty {
                    emptyState
                } else {
                    grantsList
                }
            }
            .background(Color.incBg.ignoresSafeArea())
            .navigationTitle("RSU grants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.incText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GrantFormView(store: store, onSaved: onChanged)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.incSage)
                    }
                    .accessibilityLabel("Add grant")
                }
            }
        }
        .presentationDetents([.large])
        .task {
            if !store.hasLoaded { await store.load() }
        }
        .overlay(alignment: .bottom) {
            if let message = store.errorMessage {
                errorToast(message)
            }
        }
    }

    private var grantsList: some View {
        List {
            ForEach(store.grants) { grant in
                NavigationLink {
                    GrantDetailView(store: store, grant: grant, onChanged: onChanged)
                } label: {
                    GrantRow(grant: grant)
                }
                .listRowBackground(Color.incSurface)
            }
            .onDelete { offsets in
                let doomed = offsets.map { store.grants[$0] }
                Task {
                    for grant in doomed { await store.delete(grant) }
                    onChanged()
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("Estimates value all \(String(AppConfig.taxYear)) vests at today's price. Actual tax withholding happens at each vest at that day's price.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.incTextDim)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.incSageBg)
                    .frame(width: 56, height: 56)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.incSage)
            }
            Text("No grants yet")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.incText)
            Text("Add an RSU grant to see how shares vest and\nwhat lands in this year's paycheck.")
                .font(.system(size: 13))
                .foregroundColor(.incTextDim)
                .multilineTextAlignment(.center)
            NavigationLink {
                GrantFormView(store: store, onSaved: onChanged)
            } label: {
                Text("+ Add grant")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incBtnSolid))
                    .foregroundColor(.incBtnSolidText)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorToast(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.incRed))
            .padding(.bottom, 18)
            .task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                store.errorMessage = nil
            }
    }
}

private struct GrantRow: View {
    let grant: RsuGrant

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(grant.ticker ?? grant.company ?? "—")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.incText)
                if grant.ticker != nil, let company = grant.company {
                    Text(company)
                        .font(.system(size: 13))
                        .foregroundColor(.incTextDim)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(formatShares(grant.sharesTotal)) sh")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.incTextDim)
                    .monospacedDigit()
            }
            Text(grant.schedule.label)
                .font(.system(size: 12))
                .foregroundColor(.incTextMute)
            HStack {
                Text("Vesting in \(String(AppConfig.taxYear)): \(formatWholeCurrency(vestingThisYear))")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.incSage)
                Spacer()
                if let next = VestMath.nextVest(for: grant) {
                    Text("Next vest \(next.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11.5))
                        .foregroundColor(.incTextMute)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var vestingThisYear: Double {
        VestMath.value(inYear: AppConfig.taxYear, grants: [grant])
    }
}
