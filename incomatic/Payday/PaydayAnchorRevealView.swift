//
//
//  PaydayAnchorRevealView.swift
//  incomatic
//
//  Created by Ben Makusha on 08/14/2026
//
//  Candidate A: the anchor ask inside the results reveal.
//
//  The number appears first, then one step asks for the date as a way of
//  SHARPENING the thing they just received. This is the placement that completes
//  best, because the value is already in the room — the cost is that it delays
//  the payoff by one screen, which is why it is shown once and never again.
//

import SwiftUI

struct PaydayAnchorRevealView: View {
    let net: Double
    let frequency: PayFrequency
    /// Called with the anchor when one is set, or nil when the user declines.
    let onFinish: (PayAnchor?) -> Void

    @State private var draft: PayAnchor
    @State private var confirmed = false

    init(net: Double,
         frequency: PayFrequency,
         onFinish: @escaping (PayAnchor?) -> Void) {
        self.net = net
        self.frequency = frequency
        self.onFinish = onFinish
        _draft = State(initialValue: PayAnchor.draft(for: frequency))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Divider()
                        .background(Color.incHairline)
                        .padding(.bottom, 22)
                    pitch
                    if confirmed {
                        AnchorConfirmation(anchor: draft, net: net)
                    } else {
                        IncCard {
                            AnchorEditor(frequency: frequency, anchor: $draft)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
            footer
        }
        .background(Color.incBg.ignoresSafeArea())
    }

    // The figure they came for, shown before anything is asked of them.
    private var header: some View {
        VStack(spacing: 2) {
            Text("YOUR TAKE-HOME")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.incTextMute)
            Text(formatCurrency(net))
                .font(.system(size: 44, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 6)
            Text(cadenceLine)
                .font(.system(size: 13))
                .foregroundColor(.incTextDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 22)
    }

    private var pitch: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("One more thing and this gets useful")
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundColor(.incText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tell us when this money actually lands and we can count down to it, on your Home Screen and in a nudge on the day.")
                .font(.system(size: 13.5))
                .foregroundColor(.incTextDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 16)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                if confirmed {
                    onFinish(draft)
                } else {
                    // Confirm in place rather than dismissing straight away, so
                    // the derived date and any weekend shift are visible before
                    // the screen goes. Otherwise the rule is invisible until the
                    // countdown disagrees with the user two weeks later.
                    withAnimation { confirmed = true }
                }
            } label: {
                Text(confirmed ? "Done" : "Set my payday")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(draft.isComplete ? Color.incSage : Color.incDisabled)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!draft.isComplete)

            if !confirmed {
                Button { onFinish(nil) } label: {
                    Text("Not now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.incTextDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .background(Color.incBg)
    }

    private var cadenceLine: String {
        switch frequency {
        case .weekly:      return "every week"
        case .biweekly:    return "every two weeks"
        case .semiMonthly: return "twice a month"
        case .monthly:     return "every month"
        case .daily:       return "every day"
        case .quarterly:   return "every quarter"
        case .semiAnnual:  return "twice a year"
        case .annual:      return "once a year"
        }
    }
}
