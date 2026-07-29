//
//
//  KeyboardDoneToolbar.swift
//  incomatic
//
//  Created by Ben Makusha on 07/26/2026
//
//  numberPad and decimalPad have no return key, so a field using them can't be
//  dismissed by keyboard alone — the pad sits over the CTA and traps the user.
//  Attach `.keyboardDoneToolbar()` to give the keypad a "Done" bar.
//
//  Apply it ONCE per hosting context (screen root or sheet), NOT per field:
//  SwiftUI renders the union of every `.keyboard` toolbar in the hierarchy, so
//  one modifier per numeric field would stack one Done bar per field on screen.
//  A sheet is its own hosting context, so each sheet needs its own.
//

import SwiftUI
import UIKit

private struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.incText)
            }
        }
    }
}

extension View {
    /// Adds a "Done" bar above the number/decimal pad so the field can be
    /// dismissed. Apply to number/decimal-pad TextFields.
    func keyboardDoneToolbar() -> some View {
        modifier(KeyboardDoneToolbar())
    }
}
