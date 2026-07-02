//
//  AccountSheet.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Bottom sheet shown from the Calculator top-bar avatar and from any sign-in
//  prompt elsewhere in the app. Two states: signed-out (sign-in CTA) and
//  signed-in (profile + saved count + sign-out).
//

import AuthenticationServices
import SwiftUI

struct AccountSheet: View {
    @ObservedObject var accountManager: AccountManager
    let savedCount: Int
    let onClose: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if accountManager.isSignedIn {
                signedInState
            } else {
                signedOutState
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 28)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.incSurface)
    }

    // MARK: - Signed-out

    private var signedOutState: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.incSageBg)
                Image(systemName: "person")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.incSage)
            }
            .frame(width: 66, height: 66)
            .padding(.bottom, 16)

            Text("Save your calculations")
                .font(.system(size: 26, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .kerning(-0.5)
                .multilineTextAlignment(.center)

            Text("Sign in to keep your take-home projections in sync across your devices.")
                .font(.system(size: 14))
                .foregroundColor(.incTextDim)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.top, 8)
                .padding(.bottom, 22)

            SignInWithAppleButton(.signIn) { request in
                accountManager.prepareAppleRequest(request)
            } onCompletion: { result in
                Task {
                    await accountManager.handleAppleResult(result)
                    if accountManager.isSignedIn { onClose() }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13).strokeBorder(Color.incHairlineStrong, lineWidth: 1)
            )
            .disabled(accountManager.isSigningIn)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.incTextMute)
                Text("Sign in with Apple keeps your email private. Your calculations stay tied to your account only.")
                    .font(.system(size: 12))
                    .foregroundColor(.incTextMute)
                    .lineSpacing(2)
            }
            .padding(.top, 16)
            .padding(.horizontal, 4)

            if let error = accountManager.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.incRed)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

            Button(action: onClose) {
                Text("Not now")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.incTextDim)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 14)
        }
    }

    // MARK: - Signed-in

    private var signedInState: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().fill(Color.incSage)
                    Text(accountManager.currentUser?.initials ?? "?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .kerning(0.4)
                }
                .frame(width: 60, height: 60)
                .shadow(color: Color.incSage.opacity(0.32), radius: 14, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(accountManager.currentUser?.displayName ?? "Signed in")
                        .font(.system(size: 24, weight: .medium, design: .serif))
                        .foregroundColor(.incText)
                        .kerning(-0.5)
                    HStack(spacing: 6) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.incTextDim)
                        Text("Signed in with Apple")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.incTextDim)
                    }
                }
                Spacer()
            }
            .padding(.top, 4)

            Rectangle()
                .fill(Color.incHairline)
                .frame(height: 1)
                .padding(.vertical, 20)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved calculations")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.incText)
                    Text("Synced to your account")
                        .font(.system(size: 12.5))
                        .foregroundColor(.incTextMute)
                }
                Spacer()
                Text("\(savedCount)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.incSageDeep)
                    .monospacedDigit()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.incSageBg))
            }
            .padding(.bottom, 22)

            Button {
                accountManager.signOut()
                onClose()
            } label: {
                Text("Sign Out")
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundColor(.incRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Color.incRed.opacity(0.12)))
            }

            Button {
                showDeleteConfirm = true
            } label: {
                Group {
                    if accountManager.isDeletingAccount {
                        ProgressView().tint(.incTextMute)
                    } else {
                        Text("Delete Account")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.incTextMute)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .padding(.top, 6)
            .disabled(accountManager.isDeletingAccount)
        }
        .alert("Delete account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await accountManager.deleteAccount() { onClose() }
                }
            }
        } message: {
            Text("This permanently deletes your account and every saved calculation. This can't be undone.")
        }
    }
}
