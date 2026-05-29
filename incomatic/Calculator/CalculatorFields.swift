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
                TextField(placeholder, text: text)
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
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.incText)
                .padding(.bottom, 8)
                .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
        }
        .padding(.bottom, 18)
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
