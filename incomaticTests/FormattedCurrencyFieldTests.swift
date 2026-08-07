//
//  FormattedCurrencyFieldTests.swift
//  incomaticTests
//
//  Guards the regression this file was written for: the field uses .decimalPad,
//  which has no return key, and it is a UIViewRepresentable — so SwiftUI's
//  .toolbar(placement: .keyboard) does not reach it. Losing the accessory bar
//  traps the user behind the keypad on every currency field in the app.
//

import SwiftUI
import UIKit
import XCTest
@testable import Incomatic

@MainActor
final class FormattedCurrencyFieldTests: XCTestCase {

    private var window: UIWindow?

    /// `makeUIView` takes a `Context` that cannot be constructed directly, so the
    /// field is driven through a real hosting controller in a real window — which
    /// is also the only way the representable actually instantiates its UIView.
    private func makeField() throws -> UITextField {
        let host = UIHostingController(
            rootView: FormattedCurrencyField(text: .constant(""), placeholder: "0.00"))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 100))
        window.rootViewController = host
        window.isHidden = false
        window.layoutIfNeeded()
        self.window = window

        return try XCTUnwrap(firstTextField(in: host.view), "representable did not build its UITextField")
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func firstTextField(in view: UIView) -> UITextField? {
        if let field = view as? UITextField { return field }
        for subview in view.subviews {
            if let found = firstTextField(in: subview) { return found }
        }
        return nil
    }

    func test_theKeypadCanAlwaysBeDismissed() throws {
        let field = try makeField()

        // decimalPad has no return key, so without an accessory view there is no
        // way out of the field at all.
        XCTAssertEqual(field.keyboardType, .decimalPad)
        XCTAssertNotNil(field.inputAccessoryView,
                        "SwiftUI's keyboard toolbar does not reach a UIViewRepresentable")
    }

    func test_theAccessoryBarOffersExactlyOneDoneAction() throws {
        let field = try makeField()
        let bar = field.inputAccessoryView as? UIToolbar

        XCTAssertNotNil(bar)
        let titles = (bar?.items ?? []).compactMap(\.title)
        XCTAssertEqual(titles, ["Done"], "a second bar item would read as two competing exits")
    }
}
