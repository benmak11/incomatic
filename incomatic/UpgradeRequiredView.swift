//
//  UpgradeRequiredView.swift
//  incomatic
//
//  Created by Ben Makusha on 08/06/2026
//
//  Shown when the backend refuses this build with a 426. Deliberately has no
//  dismiss: the block is server-side and every screen behind it would fail.
//

import SwiftUI

struct UpgradeRequiredView: View {
    let requirement: UpgradeRequirement

    @Environment(\.openURL) private var openURL

    /// Falls back to our own wording when the backend sent none, so the screen
    /// is never blank just because the payload changed shape.
    private var message: String {
        let sent = requirement.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let sent, !sent.isEmpty { return sent }
        return "This version of Incomatic is no longer supported. "
            + "Update to the latest version to continue."
    }

    private var currentVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "unknown"
    }

    var body: some View {
        ZStack {
            Color.incBg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.incSageBg)
                        .frame(width: 96, height: 96)
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Color.incSage)
                }
                .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Time for an update")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(Color.incText)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.incTextDim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    if let appStoreURL = APISession.appStoreURL {
                        Button {
                            openURL(appStoreURL)
                        } label: {
                            Text("Update Incomatic")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.incBtnSolidText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.incBtnSolid)
                                )
                        }
                        .accessibilityLabel("Update Incomatic in the App Store")
                    }

                    Text(versionFootnote)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.incTextMute)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private var versionFootnote: String {
        guard let minimum = requirement.minimumVersion, !minimum.isEmpty else {
            return "This build is version \(currentVersion)."
        }
        return "This build is version \(currentVersion). Version \(minimum) or later is required."
    }
}

#Preview("Upgrade required") {
    UpgradeRequiredView(
        requirement: UpgradeRequirement(
            message: "This version of Incomatic is no longer supported. "
                + "Update to the latest version to continue.",
            minimumVersion: "1.9.0"
        )
    )
}
