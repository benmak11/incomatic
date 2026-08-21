//
//
//  AnchorEditorView.swift
//  incomatic
//
//  Created by Ben Makusha on 08/14/2026
//
//  One editor body, three placements. Whichever container ships, the question,
//  the day-of-month rule, the weekend handling and the varies escape hatch stay
//  identical, so the decision is about WHERE to ask rather than what to ask.
//

import SwiftUI

// MARK: - Shared editor

struct AnchorEditor: View {
    let frequency: PayFrequency
    @Binding var anchor: PayAnchor
    var compact = false

    private var shape: PayAnchorKind { PayAnchor.shape(for: frequency) }
    private var varies: Bool { anchor.kind == .varies }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            if varies {
                AnchorVariesNote(frequency: frequency)
            } else if shape == .dayOfMonth {
                AnchorDayOfMonth(days: $anchor.days, frequency: frequency)
            } else {
                AnchorDatePicker(lastPaid: $anchor.lastPaid)
            }

            if !varies {
                AnchorShiftRulePicker(rule: $anchor.shiftRule)
            }

            Button(action: toggleVaries) {
                Text(varies ? "My pay is on a set schedule" : "My pay dates change")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.incSage)
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleVaries() {
        if varies {
            anchor = PayAnchor.draft(for: frequency)
        } else {
            // Keep whatever date we already have: someone flipping to "varies"
            // has usually just told us when they were last paid.
            anchor = PayAnchor(kind: .varies,
                               frequency: frequency,
                               lastPaid: anchor.lastPaid ?? Date())
        }
    }
}

// MARK: - Interval capture

/// A two-week strip rather than a full month grid. For an interval schedule the
/// only thing needed is the most recent payday, which is always within 14 days,
/// and a full calendar invites scrolling to a date that cannot be the answer.
struct AnchorDatePicker: View {
    @Binding var lastPaid: Date?
    var today: Date = Date()

    private var calendar: Calendar { .current }

    private var days: [Date] {
        let start = calendar.startOfDay(for: today)
        return (0..<14).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: start)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("When did your last paycheck land?")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.incText)
            Text("We count forward from there. One tap and you never have to think about it again.")
                .font(.system(size: 12))
                .foregroundColor(.incTextDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            let rows = [Array(days.prefix(7)), Array(days.suffix(7))]
            VStack(spacing: 6) {
                // Weekday initials come from the first row rather than a
                // hardcoded Sun-to-Sat, since the strip starts 13 days ago.
                HStack(spacing: 6) {
                    ForEach(rows[0], id: \.self) { day in
                        Text(PaydayFormat.weekdayInitial(day))
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.4)
                            .foregroundColor(.incTextMute)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { day in
                            dayCell(day)
                        }
                    }
                }
            }
            .padding(.top, 12)

            if let lastPaid,
               let preview = PaydayCalculator.info(
                    for: PayAnchor(kind: .interval, frequency: .biweekly,
                                   lastPaid: lastPaid, shiftRule: .before),
                    net: 0) {
                Text("Next payday \(PaydayFormat.date(preview.date))")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.incSageDeep)
                    .padding(.top, 12)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = lastPaid.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDate(day, inSameDayAs: today)
        // Non-banking days are dimmed, not disabled: plenty of people are paid
        // on a day the Fed is closed, they just were not paid by ACH that day.
        let muted = PaydayCalculator.isNonBanking(day)

        return Button {
            lastPaid = calendar.startOfDay(for: day)
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 14, weight: selected ? .bold : .medium))
                .foregroundColor(selected ? .white : (muted ? .incTextMute : .incText))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selected ? Color.incSage : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isToday && !selected ? Color.incHairlineStrong : .clear,
                                      lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PaydayFormat.date(day))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Day-of-month capture

/// Semi-monthly and monthly are day-of-month rules. "Last day" is a first-class
/// option because it is the most common monthly arrangement and cannot be
/// expressed as a number that survives February.
struct AnchorDayOfMonth: View {
    @Binding var days: [MonthDay]
    let frequency: PayFrequency

    private var maxDays: Int { frequency == .monthly ? 1 : 2 }

    private var presets: [(label: String, days: [MonthDay])] {
        frequency == .monthly
            ? [("Last day of the month", [.last]), ("1st", [.day(1)]), ("15th", [.day(15)])]
            : [("15th and last day", [.day(15), .last]), ("1st and 15th", [.day(1), .day(15)])]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Which days of the month do you get paid?")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.incText)
            Text("\(frequency == .monthly ? "Pick the day." : "Pick both days.") Short months are handled for you.")
                .font(.system(size: 12))
                .foregroundColor(.incTextDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            VStack(spacing: 8) {
                ForEach(presets, id: \.label) { preset in
                    presetRow(preset.label, preset.days)
                }
            }
            .padding(.top, 12)

            Text("OR PICK YOUR OWN")
                .font(.system(size: 11.5, weight: .bold))
                .tracking(0.3)
                .foregroundColor(.incTextMute)
                .padding(.top, 14)
                .padding(.bottom, 8)

            // 1 to 28 only. Offering 29 to 31 invites picking a day that does
            // not exist in February, and "last day" already covers that intent.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7),
                      spacing: 5) {
                ForEach(1...28, id: \.self) { day in
                    numberCell(day)
                }
            }
            lastDayCell
                .padding(.top, 5)
        }
    }

    private func presetRow(_ label: String, _ preset: [MonthDay]) -> some View {
        let active = Set(preset) == Set(days)
        return Button { days = preset } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(active ? Color.incSage : Color.incHairlineStrong, lineWidth: 1.5)
                        .background(Circle().fill(active ? Color.incSage : .clear))
                        .frame(width: 18, height: 18)
                    if active {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(active ? .incSageDeep : .incText)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(active ? Color.incSageBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(active ? Color.incSageSoft : Color.incHairline, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private func numberCell(_ day: Int) -> some View {
        let entry = MonthDay.day(day)
        let active = days.contains(entry)
        return Button { toggle(entry) } label: {
            Text("\(day)")
                .font(.system(size: 12.5, weight: active ? .bold : .medium))
                .foregroundColor(active ? .white : .incTextDim)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(active ? Color.incSage : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(active ? Color.incSage : Color.incHairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(MonthDay.ordinal(day))
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private var lastDayCell: some View {
        let active = days.contains(.last)
        return Button { toggle(.last) } label: {
            Text("Last day of the month")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(active ? .white : .incTextDim)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(active ? Color.incSage : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(active ? Color.incSage : Color.incHairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    /// Selecting past the cadence's limit drops the oldest choice rather than
    /// refusing the tap, so the control never feels stuck.
    private func toggle(_ entry: MonthDay) {
        if let index = days.firstIndex(of: entry) {
            days.remove(at: index)
            return
        }
        var next = days + [entry]
        if next.count > maxDays { next.removeFirst(next.count - maxDays) }
        days = next
    }
}

// MARK: - Shift rule

struct AnchorShiftRulePicker: View {
    @Binding var rule: PayShiftRule

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("If payday lands on a weekend or holiday")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.incText)
            Text("This happens twice a year on average. Getting it right keeps the countdown honest.")
                .font(.system(size: 12))
                .foregroundColor(.incTextDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            VStack(spacing: 6) {
                ForEach(PayShiftRule.allCases, id: \.self) { option in
                    row(option)
                }
            }
            .padding(.top, 10)
        }
    }

    private func row(_ option: PayShiftRule) -> some View {
        let active = rule == option
        return Button { rule = option } label: {
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(active ? Color.incSage : Color.incHairlineStrong, lineWidth: 1.5)
                    .background(Circle().fill(active ? Color.incSage : .clear))
                    .frame(width: 16, height: 16)
                Text(option.label)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(active ? .incSageDeep : .incText)
                Spacer(minLength: 0)
                if option == .before {
                    Text("Most common")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.incTextMute)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .background(active ? Color.incSageBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(active ? Color.incSageSoft : Color.incHairline, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Varies

/// The honest answer for irregular pay: an approximate countdown, labelled as
/// approximate everywhere it appears. Being vague and saying so beats being
/// precise and wrong.
struct AnchorVariesNote: View {
    let frequency: PayFrequency

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("APPROXIMATE COUNTDOWN")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.incBlush)
            Text("We will estimate from your \(frequency.displayName.lowercased()) cadence")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.incText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
            Text("Everything will say \"about\" instead of a firm date, and the widget shows a range. You can log each real payday in one tap to sharpen it over time.")
                .font(.system(size: 12.5))
                .foregroundColor(.incTextDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.incBlushBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Confirmation

/// Shows the derived date back to the user, including the weekend shift, so the
/// rule is visibly working rather than silently applied.
struct AnchorConfirmation: View {
    let anchor: PayAnchor
    let net: Double

    var body: some View {
        if let info = PaydayCalculator.info(for: anchor, net: net) {
            VStack(alignment: .leading, spacing: 0) {
                Text("YOUR NEXT PAYDAY")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(.incSageDeep)
                Text("\(info.approximate ? "About " : "")\(PaydayFormat.date(info.date))")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundColor(.incSageDeep)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.top, 8)
                Text(explanation(info))
                    .font(.system(size: 12.5))
                    .foregroundColor(.incTextDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.incSageBg)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func explanation(_ info: PaydayInfo) -> String {
        var text = PaydayCalculator.countdownText(info)
        if info.shifted, let from = info.shiftedFrom {
            text += ", moved up from \(PaydayFormat.date(from, weekday: false)) because it falls on a \(PaydayFormat.weekday(from))"
        }
        return text + ". You can change this any time from your paycheck."
    }
}

// MARK: - Edit sheet

/// The correction path, reachable from the countdown card and from the
/// existing-user banner so nobody has to hunt through settings.
struct AnchorEditSheet: View {
    let frequency: PayFrequency
    let net: Double
    let initial: PayAnchor?
    let onSave: (PayAnchor) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: PayAnchor

    init(frequency: PayFrequency,
         net: Double,
         initial: PayAnchor?,
         onSave: @escaping (PayAnchor) -> Void) {
        self.frequency = frequency
        self.net = net
        self.initial = initial
        self.onSave = onSave
        _draft = State(initialValue: initial ?? PayAnchor.draft(for: frequency))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AnchorEditor(frequency: frequency, anchor: $draft)
                    if draft.isComplete {
                        AnchorConfirmation(anchor: draft, net: net)
                    }
                }
                .padding(20)
            }
            .background(Color.incBg)
            .navigationTitle("Edit your payday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isComplete)
                }
            }
        }
    }
}
