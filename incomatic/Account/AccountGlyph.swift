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
            .frame(width: 38, height: 38)
            .shadow(color: signedIn ? Color.incSage.opacity(0.32) : Color.black.opacity(0.04),
                    radius: signedIn ? 8 : 2,
                    x: 0,
                    y: signedIn ? 2 : 1)
        }
        .accessibilityLabel("Account")
    }
}
