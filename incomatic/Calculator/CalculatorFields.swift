//
//  
//  CalculatorFields.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Reusable form controls for the Calculator sections.
//  Underlined fields, radio rows, toggle rows, menu pickers, card headers.
//

import SwiftUI

enum CalculatorFields {
    static func fieldLabel(_ text: String, suffix: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.incTextMute)
                .kerning(0.8)
            Spacer()
            if let suffix {
                Text(suffix)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.incSage)
            }
        }
        .padding(.bottom, 6)
    }

    static func amountField(
        label: String,
        text: Binding<String>,
        suffix: String? = nil,
        placeholder: String = "0.00"
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel(label.uppercased(), suffix: suffix)
            HStack(spacing: 8) {
                Text("$").font(.system(size: 18, weight: .semibold)).foregroundColor(.incTextMute)
                TextField(placeholder, text: currencyBinding(text))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.incText)
                    .kerning(-0.3)
            }
            .padding(.bottom, 8)
            .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
        }
        .padding(.bottom, 18)
    }

    static func plainNumberField(
        label: String,
        text: Binding<String>,
        placeholder: String = "0"
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel(label.uppercased())
            TextField(placeholder, text: wholeNumberBinding(text))
                .keyboardType(.numberPad)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.incText)
                .padding(.bottom, 8)
                .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
        }
        .padding(.bottom, 18)
    }

    // MARK: - Input sanitizing / formatting
    //
    // The underlying @Observable state always stores a RAW numeric string (no
    // grouping separators) so `Double(state.x)` keeps working everywhere. These
    // bindings reformat only the *displayed* text:
    //   • currency  → digits + a single ".", max 2 decimals, live "1,234.56" grouping
    //   • whole     → digits only (hours, allowances)

    /// Display binding for `$`-prefixed currency fields. Stores raw (un-grouped),
    /// shows thousands separators while typing.
    static func currencyBinding(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { groupCurrency(source.wrappedValue) },
            set: { source.wrappedValue = sanitizeCurrency($0) }
        )
    }

    /// Display binding for whole-number fields (hours, allowances).
    static func wholeNumberBinding(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { source.wrappedValue = String($0.filter(\.isNumber)) }
        )
    }

    /// Keep digits + at most one decimal point + at most 2 fractional digits.
    /// Drops grouping commas and any other character so the result is `Double`-parseable.
    static func sanitizeCurrency(_ input: String) -> String {
        var result = ""
        var sawDot = false
        var decimals = 0
        for ch in input {
            if ch.isNumber {
                if sawDot {
                    guard decimals < 2 else { continue }
                    decimals += 1
                }
                result.append(ch)
            } else if ch == "." && !sawDot {
                sawDot = true
                result.append(ch)
            }
        }
        return result
    }

    /// Add thousands separators to the integer part of an already-sanitized raw
    /// string, preserving a trailing "." or partial decimals mid-typing.
    static func groupCurrency(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        let dotIndex = raw.firstIndex(of: ".")
        let intPart = String(dotIndex.map { raw[..<$0] } ?? Substring(raw))
        let grouped = groupedInteger(intPart)
        if let dotIndex {
            return grouped + "." + raw[raw.index(after: dotIndex)...]
        }
        return grouped
    }

    private static let groupingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private static func groupedInteger(_ digits: String) -> String {
        guard !digits.isEmpty, let value = Int(digits) else { return digits }
        return groupingFormatter.string(from: NSNumber(value: value)) ?? digits
    }

    static func radioRow<T: Equatable>(
        _ label: String,
        value: T,
        selection: Binding<T>
    ) -> some View {
        let isSelected = selection.wrappedValue == value
        return Button(action: { selection.wrappedValue = value }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.incSage : Color.incHairlineStrong, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.incSage).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                    }
                }
                Text(label)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.incText)
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    static func toggleRow(
        _ label: String,
        sub: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(.incText)
                if let sub {
                    Text(sub).font(.system(size: 12)).foregroundColor(.incTextMute)
                }
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(.incSage)
        }
        .padding(.vertical, 14)
    }

    @ViewBuilder
    static func styledMenu<Items: View>(
        label: String,
        @ViewBuilder items: () -> Items
    ) -> some View {
        Menu {
            items()
        } label: {
            HStack {
                Text(label).foregroundColor(.incText).font(.system(size: 18, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.incTextMute).font(.system(size: 13, weight: .bold))
            }
            .padding(.bottom, 8)
            .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
        }
    }

    static func cardHeader(icon: String, title: String, sub: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.incSageBg)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .foregroundColor(.incSage)
                    .font(.system(size: 15, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.incText)
                if let sub {
                    Text(sub).font(.system(size: 12)).foregroundColor(.incTextDim)
                }
            }
        }
        .padding(.bottom, 16)
    }
}
