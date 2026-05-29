//
//
//  Created by Ben Makusha on 05/28/2026
//  
//  SectionStepIndicator.swift
//  incomatic
//
//  Numbered circles + connecting progress line above the section content.
//  Completed steps show a checkmark in incSageSoft.
//

import SwiftUI

struct SectionStepIndicator: View {
    @Binding var active: CalculatorSection
    private let all = CalculatorSection.allCases

    var body: some View {
        let activeIdx = all.firstIndex(of: active) ?? 0

        ZStack(alignment: .top) {
            // Connecting line
            GeometryReader { geo in
                let inset: CGFloat = 22
                let span = geo.size.width - inset * 2
                let progress = CGFloat(activeIdx) / CGFloat(all.count - 1)
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.incHairline)
                        .frame(width: span, height: 1.5)
                    Rectangle().fill(Color.incSage)
                        .frame(width: span * progress, height: 1.5)
                        .animation(.easeInOut(duration: 0.35), value: activeIdx)
                }
                .offset(x: inset, y: 19)
            }
            .frame(height: 22)

            HStack {
                ForEach(Array(all.enumerated()), id: \.offset) { idx, sect in
                    let isActive = sect == active
                    let isDone = idx < activeIdx
                    Button(action: { active = sect }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        isActive || isDone ? Color.clear : Color.incHairlineStrong,
                                        lineWidth: 1.5
                                    )
                                    .background(
                                        Circle().fill(
                                            isActive ? Color.incSage :
                                                isDone ? Color.incSageSoft : Color.incBg
                                        )
                                    )
                                    .frame(width: 24, height: 24)
                                if isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundColor(.incSageDeep)
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(isActive ? .white : .incTextMute)
                                }
                            }
                            Text(sect.displayName)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(isActive ? .incText : .incTextMute)
                        }
                    }
                    .buttonStyle(.plain)
                    if idx < all.count - 1 { Spacer() }
                }
            }
        }
    }
}
