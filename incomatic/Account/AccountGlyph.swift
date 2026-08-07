//
//  AccountGlyph.swift
//  incomatic
//
//  Created by Ben Makusha on 06/09/2026
//
//  Circular avatar button slotted into the Calculator's top bar. Outlined when
//  signed out, filled sage with initials when signed in. Tap surfaces the
//  AccountSheet.
//

import SwiftUI

struct AccountGlyph: View {
    static let diameter: CGFloat = 38

    /// Gap between the glyph and the screen's trailing edge, applied by the host.
    static let trailingInset: CGFloat = 20

    /// Total width the floating glyph claims from the trailing edge. It is an
    /// overlay on the whole shell, so anything a header right-aligns into the same
    /// corner has to reserve this much or the glyph lands on top of it.
    static var reservedTrailingWidth: CGFloat { diameter + trailingInset }

    let signedIn: Bool
    let user: AccountUser?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if signedIn, let user {
                    Circle().fill(Color.incSage)
                    Text(user.initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .kerning(0.2)
                } else {
                    Circle().fill(Color.incSurface)
                    Circle().strokeBorder(Color.incHairlineStrong, lineWidth: 1.5)
                    Image(systemName: "person")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.incTextDim)
                }
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .shadow(color: signedIn ? Color.incSage.opacity(0.32) : Color.black.opacity(0.04),
                    radius: signedIn ? 8 : 2,
                    x: 0,
                    y: signedIn ? 2 : 1)
        }
        .accessibilityLabel("Account")
    }
}
