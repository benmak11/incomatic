//
//  OnboardingNotebookView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/21/2026
//
//  First-run Guided Notebook intake (design §A3, Claude Design "Notebook"
//  variation): app chrome (avatar + wordmark, slim progress rail) and a
//  conversation-bubble question above a card input, one question at a time.
//  Writes directly into the same CalculatorState the Calculator tab uses —
//  no separate form shape to reconcile, "edit anything later" just works.
//

import SwiftUI
import UIKit

struct OnboardingNotebookView: View {
    @Bindable var state: CalculatorState
    let userName: String?
    let onCalculate: () -> Void

    @State private var flow = OnboardingFlow()
    @State private var keyboardVisible = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    bubble
                    stepContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .id(flow.stepIndex)
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
            .animation(.easeInOut(duration: 0.3), value: flow.stepIndex)
            if !keyboardVisible {
                footer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.incBg.ignoresSafeArea())
        .task {
            if state.statesList.isEmpty {
                state.statesList = await loadUSStates()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { keyboardVisible = false }
        }
        .animation(.easeInOut(duration: 0.3), value: keyboardVisible)
    }

    // ─ Chrome ────────────────────────────────────────────────

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if !flow.isGreet {
                    Button(action: { withAnimation { flow.back() } }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.incTextMute)
                    }
                    .buttonStyle(.plain)
                }
                ZStack {
                    Circle().fill(Color.incSage).frame(width: 30, height: 30)
                    Text("i")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .italic()
                        .foregroundColor(.white)
                }
                Text("incomatic")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.incText)
                    .kerning(-0.3)
                Spacer()
            }
            .padding(.top, 16)
            .padding(.horizontal, 22)
            .padding(.bottom, 14)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.incHairline).frame(height: 2.5)
                    Capsule().fill(Color.incSage)
                        .frame(width: geo.size.width * flow.progress, height: 2.5)
                        .animation(.easeInOut(duration: 0.35), value: flow.progress)
                }
            }
            .frame(height: 2.5)
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private var bubble: some View {
        if flow.isGreet {
            VStack(alignment: .leading, spacing: 14) {
                OnboardingBubble(text: greetText)
                Text("A few quick questions and we'll build your take-home picture together. You can edit anything later.")
                    .font(.system(size: 13))
                    .foregroundColor(.incTextDim)
                    .lineSpacing(3)
            }
        } else if flow.isReview {
            OnboardingBubble(text: "Here's what we've got. Tap anything to change it.")
        } else {
            OnboardingBubble(text: questionText)
        }
    }

    private var greetText: String {
        if let userName, !userName.isEmpty {
            return "Hello, \(userName) welcome to Incomatic! The home to define your financial horizon."
        }
        return "Hello there, welcome to Incomatic! The home to define your financial horizon."
    }

    private var questionText: String {
        switch flow.step {
        case .greet, .review:  return ""
        case .wage:            return "First, let's begin by asking; what's your annual or hourly wage?"
        case .payFrequency:    return "How often do you get paid?"
        case .bonus:           return "Do you get a one-time bonus?"
        case .commission:      return "Any commission on top of that?"
        case .filingStatus:    return "What's your filing status?"
        case .state:           return "Where do you work?"
        case .benefits:        return "Any pre-tax benefits deducted each period?"
        case .retirement:      return "Setting anything aside for retirement?"
        }
    }

    // ─ Step bodies ───────────────────────────────────────────

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {
        case .greet:
            EmptyView()
        case .wage:
            wageStep
        case .payFrequency:
            payFrequencyStep
        case .bonus:
            bonusStep
        case .commission:
            commissionStep
        case .filingStatus:
            filingStatusStep
        case .state:
            stateStep
        case .benefits:
            VStack(alignment: .leading, spacing: 14) {
                benefitsStep
                skipButton
            }
        case .retirement:
            VStack(alignment: .leading, spacing: 14) {
                retirementStep
                skipButton
            }
        case .review:
            OnboardingReviewView(state: state, onEdit: { flow.jump(to: $0) })
        }
    }

    private var wageStep: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                Picker("Income Type", selection: $state.incomeType) {
                    ForEach(IncomeType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 18)
                .colorMultiply(.incSage)

                if state.incomeType == .salary {
                    CalculatorFields.amountField(label: "Annual gross", text: $state.salaryAmount)
                } else {
                    CalculatorFields.amountField(label: "Hourly rate", text: $state.hourlyRate)
                }
            }
        }
    }

    private var payFrequencyStep: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(PayFrequency.allCases, id: \.self) { freq in
                    CalculatorFields.radioRow(freq.displayName, value: freq, selection: $state.payFrequency)
                }
            }
        }
    }

    private var bonusStep: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                yesNoSegmented(selection: flow.wantsBonus) { wants in
                    flow.wantsBonus = wants
                    if !wants { state.bonusAmount = "" }
                }
                if flow.wantsBonus == true {
                    CalculatorFields.amountField(label: "Bonus amount", text: $state.bonusAmount)
                    CalculatorFields.bonusDateRow(date: $state.bonusDate)
                }
            }
        }
    }

    private var commissionStep: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                yesNoSegmented(selection: flow.wantsCommission) { wants in
                    flow.wantsCommission = wants
                    if !wants { state.commissionAmount = "" }
                }
                if flow.wantsCommission == true {
                    CalculatorFields.amountField(label: "Commission (annual)", text: $state.commissionAmount)
                }
            }
        }
    }

    private var filingStatusStep: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(FilingStatus.allCases, id: \.self) { status in
                    CalculatorFields.radioRow(status.displayName, value: status, selection: $state.filingStatus)
                }
            }
        }
    }

    private var stateStep: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                CalculatorFields.fieldLabel("STATE OR TERRITORY")
                CalculatorFields.styledMenu(
                    label: state.stateName(for: state.selectedStateCode) ?? "Select state"
                ) {
                    ForEach(state.statesList) { entry in
                        Button(entry.name) { state.selectedStateCode = entry.code }
                    }
                }
            }
        }
    }

    private var benefitsStep: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                CalculatorFields.amountField(label: "Medical", text: $state.medicalPerPeriod)
                CalculatorFields.amountField(label: "Dental", text: $state.dentalPerPeriod)
                CalculatorFields.amountField(label: "Vision", text: $state.visionPerPeriod)
                CalculatorFields.amountField(label: "Healthcare FSA", text: $state.healthcareFsaPerPeriod)
            }
        }
    }

    private var retirementStep: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                percentRow(label: "TRADITIONAL 401(K)", value: state.traditional401kPercent, binding: $state.traditional401kPercent)
                    .padding(.bottom, 18)
                percentRow(label: "ROTH 401(K)", value: state.roth401kPercent, binding: $state.roth401kPercent)
            }
        }
    }

    // ─ Small shared step controls ───────────────────────────

    private func yesNoSegmented(selection: Bool?, onSelect: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 10) {
            yesNoButton("Yes", isSelected: selection == true) { onSelect(true) }
            yesNoButton("No", isSelected: selection == false) { onSelect(false) }
        }
        .padding(.bottom, 18)
    }

    private func yesNoButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isSelected ? .incSageDeep : .incText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(isSelected ? Color.incSageBg : Color.incSurface))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isSelected ? Color.incSage : Color.incHairline, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func percentRow(label: String, value: Double, binding: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                CalculatorFields.fieldLabel(label)
                Spacer()
                Text("\(String(format: "%.1f", value))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.incSage)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(Color.incSageBg))
            }
            Slider(value: binding, in: 0...25, step: 0.5).tint(.incSage)
        }
    }

    private var skipButton: some View {
        HStack {
            Spacer()
            Button(action: { withAnimation { flow.next() } }) {
                Text("Skip for now")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.incTextMute)
                    .underline()
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // ─ Footer ────────────────────────────────────────────────

    @ViewBuilder
    private var footer: some View {
        switch flow.step {
        case .greet:
            OnboardingFooter(primaryLabel: "Get started", disabled: false, ribbon: nil) {
                withAnimation { flow.next() }
            }
        case .review:
            OnboardingFooter(
                primaryLabel: userName.map { "Looks good, \($0) calculate" } ?? "Looks good, calculate",
                disabled: false,
                ribbon: nil,
                action: onCalculate
            )
        default:
            let preview = livePreview(state: state)
            OnboardingFooter(
                primaryLabel: "Continue",
                disabled: !flow.canProceed(state: state),
                ribbon: preview.perPeriod.map { ("Projected · per \(state.payFrequency.displayName.lowercased())", $0) }
            ) {
                withAnimation { flow.next() }
            }
        }
    }
}

// MARK: - Bubble

private struct OnboardingBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.incText)
            .lineSpacing(3)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ChatBubbleShape().fill(Color.incSageBg))
            .frame(maxWidth: 320, alignment: .leading)
            .padding(.bottom, 16)
    }
}

/// Mostly-rounded rect with a sharp top-leading corner, like a chat bubble
/// pointing at the sender. Hand-rolled (not UnevenRoundedRectangle) to avoid
/// any availability risk against the 18.6 deployment target.
private struct ChatBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let sharp: CGFloat = 4
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + sharp, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + sharp))
        path.closeSubpath()
        return path
    }
}

// MARK: - Footer

private struct OnboardingFooter: View {
    let primaryLabel: String
    let disabled: Bool
    /// (label, projected per-period value) — nil hides the ribbon entirely.
    let ribbon: (String, Double)?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let ribbon {
                HStack {
                    Text(ribbon.0.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.incSageDeep)
                        .kerning(0.6)
                    Spacer()
                    Text(formatCurrency(ribbon.1))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.incSageDeep)
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.incSageBg)
                .overlay(Rectangle().fill(Color.incHairline).frame(height: 1), alignment: .bottom)
            }
            Button(action: action) {
                Text(primaryLabel)
                    .font(.system(size: 14.5, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(RoundedRectangle(cornerRadius: 14).fill(disabled ? Color.incDisabled : Color.incSage))
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .padding(10)
        }
        .background(Color.incSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.incHairline, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 22, x: 0, y: 6)
        .padding(.horizontal, 14)
        .padding(.bottom, 26)
    }
}
