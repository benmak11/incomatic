//
//
//  PaydayPromptViews.swift
//  incomatic
//
//  Created by Ben Makusha on 08/14/2026
//
//  The priming sheet that earns the notification permission, and the two-pass
//  banner that reaches the existing install base.
//

import SwiftUI

// MARK: - Notification priming

/// Shown immediately after the anchor is saved, which is the only moment the
/// value of the notification is self-evident.
///
/// The system prompt fires only after the user taps the affirmative here, so a
/// decline costs nothing: iOS gives one shot at the real prompt, and spending it
/// on someone who would have said no burns it permanently.
struct NotifPrimingSheet: View {
    let net: Double
    let onDecided: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            NotificationPreview(message: "\(formatCurrency(net)) lands today. Tap to see where it goes.")
                .frame(maxWidth: 300)
                .padding(.bottom, 18)

            Text("Want this on payday?")
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .multilineTextAlignment(.center)
            Text("One notification per paycheck, on the morning it lands, with the amount in it. Nothing else, ever.")
                .font(.system(size: 13.5))
                .foregroundColor(.incTextDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Button {
                    Task {
                        let granted = await PaydayNotificationScheduler.requestAuthorization()
                        onDecided(granted)
                        dismiss()
                    }
                } label: {
                    Text("Yes, remind me on payday")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.incSage)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onDecided(false)
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.incTextDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
        .background(Color.incBg)
    }
}

/// A still of the notification the user is being asked to allow. Showing the
/// actual alert is the argument.
struct NotificationPreview: View {
    /// Named `message` rather than `body` so it does not collide with the
    /// View protocol's own requirement.
    let message: String
    var time = "8:00 AM"

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.incSage)
                .frame(width: 38, height: 38)
                .overlay(
                    Text("i")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .italic()
                        .foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text("Incomatic")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 8)
                    Text(time)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Text(message)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Existing-user banner

/// Everyone already installed has `hasCompletedOnboarding = true` and will never
/// see onboarding again. Without this the loop launches to new installs only.
///
/// Two passes, then it stops asking:
///   1  a quiet single line, dismissible
///   2  the widget preview, shown once, and only if pass 1 was dismissed without
///      action and the user has since run a calculation
///   after  never again; the entry point moves to Account permanently
struct ExistingUserBanner: View {
    let pass: Int
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if pass == 1 { quietLine } else { previewCard }
    }

    private var quietLine: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.incSage)
            Group {
                Text("New: count down to payday. ")
                    .foregroundColor(.incText)
                + Text("Add yours")
                    .foregroundColor(.incSageDeep)
                    .fontWeight(.bold)
                    .underline()
            }
            .font(.system(size: 12.5))
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            dismissButton
        }
        .padding(.vertical, 11)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .background(Color.incSageBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onAdd)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                PaydayWidgetPreview()
                VStack(alignment: .leading, spacing: 5) {
                    Text("Put your paycheck on your Home Screen")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.incText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Tell us your payday once and Incomatic counts down to it.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.incTextDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button(action: onAdd) {
                    Text("Add my payday")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                        .background(Color.incSage)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                Button(action: onDismiss) {
                    Text("No thanks")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.incTextDim)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.incSageBg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) { dismissButton.padding(12) }
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.incTextMute)
                .padding(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
    }
}

/// A still of the small widget, used to sell the widget inside the app. Not the
/// widget itself: the extension renders its own, and coupling the two would drag
/// WidgetKit into the app target for a picture.
struct PaydayWidgetPreview: View {
    var days = 3
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle()
                    .fill(Color.incSage)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Text("i")
                            .font(.system(size: 8, weight: .bold, design: .serif))
                            .italic()
                            .foregroundColor(.white)
                    )
                Spacer()
                PaydayRing(size: 18, stroke: 2.5, progress: 0.78) { EmptyView() }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(days)")
                    .font(.system(size: 26, weight: .medium, design: .serif))
                    .foregroundColor(.incText)
                Text("days")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.incTextDim)
            }
            Text("until payday")
                .font(.system(size: 8.5))
                .foregroundColor(.incTextDim)
        }
        .padding(11)
        .frame(width: 98, height: 98)
        .background(Color.incSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityHidden(true)
    }
}
