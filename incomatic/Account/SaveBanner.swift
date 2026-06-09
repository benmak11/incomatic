//
//  SaveBanner.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Floating sign-in nudge shown on the Insights tab after an anonymous
//  calculation completes. Mirrors auth-flow.jsx:489-516.
//

import SwiftUI

struct SaveBanner: View {
    @Binding var isVisible: Bool
    let onSignIn: () -> Void
    var onDismiss: (() -> Void)? = nil

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.incSageBg)
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.incSage)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Save this calculation")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.incText)
                    Text("Sign in to keep it in History.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.incTextDim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onSignIn) {
                    Text("Sign in")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Color.incText))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.incSurface)
                    .shadow(color: Color.incText.opacity(0.14), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18).strokeBorder(Color.incHairline, lineWidth: 1)
            )
            .padding(.horizontal, 14)
        }
        .offset(x: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { value in
                    // Only track horizontal swipes
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 80
                    if abs(value.translation.width) > threshold {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = value.translation.width > 0 ? 500 : -500
                            isVisible = false
                        }
                        onDismiss?()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: dragOffset)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    @Previewable @State var isVisible: Bool = true
    return VStack {
        if isVisible {
            SaveBanner(isVisible: .constant(true), onSignIn: {}, onDismiss: {})
        }
        Spacer()
    }
    .padding()
}
