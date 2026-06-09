//
//  SavedToast.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Dark pill toast that appears briefly after a successful auto-save.
//  Mirrors auth-flow.jsx:518-531.
//

import SwiftUI

struct SavedToast: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.incSageSoft)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color.incText))
        .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 8)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
