//
//  HistoryTab.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Three states: signed-out (sign-in CTA card), signed-in empty (calendar
//  prompt), signed-in with sessions (card of SessionRows). Tapping a row pushes
//  the SessionDetailView.
//

import AuthenticationServices
import SwiftUI

struct HistoryTab: View {
    @ObservedObject var accountManager: AccountManager
    @ObservedObject var viewModel: HistoryViewModel
    let onShowAccount: () -> Void
    /// Reports scroll direction so the shell's floating pill nav shrinks the
    /// same way here as it does on Calculator.
    var onScrollDirectionChange: (Bool) -> Void = { _ in }
    @State private var selected: SavedCalculationSummary?
    @State private var deleting: Bool = false

    var body: some View {
        ZStack {
            Color.incBg.ignoresSafeArea()

            if let summary = selected {
                SessionDetailView(
                    summary: summary,
                    onBack: { selected = nil },
                    onDelete: { await delete(id: summary.id) },
                    viewModel: viewModel,
                    onScrollDirectionChange: onScrollDirectionChange
                )
            } else {
                listScroll
            }
        }
        .task(id: accountManager.isSignedIn) { await viewModel.load() }
    }

    private var listScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                AppSectionHeader(title: "History")
                pageSubtitle
                content
            }
            .padding(.bottom, 120)
        }
        .reportingScrollDirection(onScrollDirectionChange)
        .refreshable { await viewModel.load() }
    }

    private var pageSubtitle: some View {
        Text(accountManager.isSignedIn
             ? "Your saved take-home projections, synced to your account."
             : "Keep a record of every projection you run.")
            .font(.system(size: 14))
            .foregroundColor(.incTextDim)
            .lineSpacing(3)
            .frame(maxWidth: 290, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
    }

    @ViewBuilder
    private var content: some View {
        if !accountManager.isSignedIn {
            signedOutCard
        } else if viewModel.isLoading && viewModel.sessions.isEmpty {
            VStack { ProgressView().tint(.incSage).padding(.top, 40) }
                .frame(maxWidth: .infinity)
        } else if viewModel.sessions.isEmpty {
            signedInEmpty
        } else {
            sessionsList
        }
    }

    private var signedOutCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.incSageBg).frame(width: 76, height: 76)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.incSage)
            }

            Text("Sign in to save and\nview past calculations")
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .multilineTextAlignment(.center)
                .kerning(-0.5)

            Text("Every calculation you run is saved privately to your account and synced across devices.")
                .font(.system(size: 13.5))
                .foregroundColor(.incTextDim)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 270)

            SignInWithAppleButton(.signIn) { request in
                accountManager.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await accountManager.handleAppleResult(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(Color.incHairlineStrong, lineWidth: 1)
            )

            if let error = accountManager.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.incRed)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.incSurface))
        .padding(.horizontal, 16)
    }

    private var signedInEmpty: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.incSageBg).frame(width: 80, height: 80)
                Image(systemName: "calendar")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.incSage)
            }
            .padding(.bottom, 8)

            Text("No saved calculations yet")
                .font(.system(size: 25, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .kerning(-0.5)

            Text("Run a projection from the Calculator tab and it will be saved here automatically.")
                .font(.system(size: 14))
                .foregroundColor(.incTextDim)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 270)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.bottom, 60)
    }

    private var sessionsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(viewModel.sessions.count) SAVED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.incTextMute)
                    .kerning(0.8)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { idx, summary in
                    SessionRow(
                        summary: summary,
                        isLast: idx == viewModel.sessions.count - 1,
                        onTap: { selected = summary }
                    )
                }
            }
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.incSurface))
            .padding(.horizontal, 16)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.incRed)
                    .padding(.top, 10)
                    .padding(.horizontal, 22)
            }
        }
    }

    private func delete(id: String) async {
        guard !deleting else { return }
        deleting = true
        defer { deleting = false }
        await viewModel.delete(id)
        selected = nil
    }
}
