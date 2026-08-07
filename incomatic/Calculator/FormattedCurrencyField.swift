//
//  FormattedCurrencyField.swift
//  incomatic
//
//  Created by Ben Makusha on 08/02/2026
//
//  A plain SwiftUI TextField bound through a formatted Binding(get:set:)
//  does NOT push the transformed get() value back into the underlying
//  UITextField while that field still holds first-responder/keyboard
//  focus — confirmed interactively this session (typing shows raw digits
//  the whole way through; the display only snaps to the grouped value the
//  instant the field resigns first responder). That's a real UIKit-
//  bridging constraint, not something a SwiftUI modifier can configure
//  away, so this wraps a real UITextField with a delegate that rewrites
//  its own displayed text (and repositions the cursor) on every keystroke
//  — the standard iOS pattern for genuinely live-formatted input.
//

import SwiftUI
import UIKit

struct FormattedCurrencyField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .decimalPad
        field.font = .systemFont(ofSize: 22, weight: .semibold)
        field.textColor = UIColor(Color.incText)
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(Color.incTextMute)]
        )
        field.delegate = context.coordinator
        // .decimalPad has no return key, and SwiftUI's .toolbar(placement: .keyboard)
        // does NOT reach a UITextField inside a UIViewRepresentable — it only decorates
        // SwiftUI's own text input. Without this the pad covers the CTA with no way out.
        field.inputAccessoryView = Self.makeDoneBar(for: field)
        field.text = CalculatorFields.groupCurrency(text)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only reconcile when the change came from outside this field
        // (e.g. Onboarding Review's "jump to edit" pre-fill) — while the
        // user is actively editing, the coordinator already keeps
        // uiView.text in sync, so overwriting it here would fight typing.
        let grouped = CalculatorFields.groupCurrency(text)
        if uiView.text != grouped && !uiView.isFirstResponder {
            uiView.text = grouped
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    /// Matches the SwiftUI `.keyboardDoneToolbar()` used by the plain numeric fields, so
    /// the two mechanisms look like one control to the user. They never appear together:
    /// each decorates only the field type it belongs to.
    private static func makeDoneBar(for field: UITextField) -> UIToolbar {
        let bar = UIToolbar()
        bar.sizeToFit()
        // Without an explicit background the bar renders transparent and the button
        // floats over the page as a tinted pill. configureWithDefaultBackground gives
        // it the same chrome the SwiftUI keyboard toolbar draws for the plain fields.
        let appearance = UIToolbarAppearance()
        appearance.configureWithDefaultBackground()
        bar.standardAppearance = appearance
        bar.compactAppearance = appearance
        // Tint drives the item colour; title attributes alone lose to the system tint.
        bar.tintColor = UIColor(Color.incText)
        let done = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: field,
            action: #selector(UIResponder.resignFirstResponder)
        )
        done.setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: 16, weight: .semibold),
             .foregroundColor: UIColor(Color.incText)],
            for: .normal
        )
        bar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            done,
        ]
        return bar
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        // Handles paste, autofill, and any other UIKit-driven text change
        // that doesn't route through shouldChangeCharactersIn (e.g. the
        // system's own "Fill Password"/QuickType bar) by re-sanitizing
        // and re-grouping whatever UIKit ended up setting.
        @objc func editingChanged(_ field: UITextField) {
            let sanitized = CalculatorFields.sanitizeCurrency(field.text ?? "")
            let grouped = CalculatorFields.groupCurrency(sanitized)
            if field.text != grouped {
                field.text = grouped
            }
            if text.wrappedValue != sanitized {
                text.wrappedValue = sanitized
            }
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString: String
        ) -> Bool {
            let current = textField.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return true }
            let proposed = current.replacingCharacters(in: swiftRange, with: replacementString)

            let sanitized = CalculatorFields.sanitizeCurrency(proposed)
            let grouped = CalculatorFields.groupCurrency(sanitized)

            // Cursor offset in the OLD (grouped) displayed string, then
            // mapped to the NEW (grouped) string by walking both strings
            // and tracking how the raw (digit) position shifts — same
            // iterative approach as Android's ThousandsSeparatorVisualTransformation.
            let oldCursorOffset = textField.offset(from: textField.beginningOfDocument, to: textField.selectedTextRange?.start ?? textField.endOfDocument)
            let oldRawOffset = rawOffset(forDisplayOffset: oldCursorOffset, in: current)
            let insertedRawCount = CalculatorFields.sanitizeCurrency(replacementString).count
            let deletedRawCount = CalculatorFields.sanitizeCurrency(String(current[swiftRange])).count
            let newRawOffset = max(0, oldRawOffset - deletedRawCount + insertedRawCount)
            let newDisplayOffset = displayOffset(forRawOffset: newRawOffset, in: grouped)

            textField.text = grouped
            if let newPosition = textField.position(from: textField.beginningOfDocument, offset: newDisplayOffset) {
                textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
            }

            if text.wrappedValue != sanitized {
                text.wrappedValue = sanitized
            }
            return false
        }

        /// Raw (un-grouped) character count before `displayOffset` in `displayed`.
        private func rawOffset(forDisplayOffset displayOffset: Int, in displayed: String) -> Int {
            let prefix = displayed.prefix(displayOffset)
            return prefix.filter { $0 != "," }.count
        }

        /// Display offset in `displayed` that corresponds to `rawOffset` raw characters.
        private func displayOffset(forRawOffset rawOffset: Int, in displayed: String) -> Int {
            var seenRaw = 0
            for (i, ch) in displayed.enumerated() {
                if seenRaw >= rawOffset { return i }
                if ch != "," { seenRaw += 1 }
            }
            return displayed.count
        }
    }
}
