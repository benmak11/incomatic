//
//  MiniDonut.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Tiny 3-wedge donut used in the History row. Matches the colors of the
//  Insights hero donut (take-home sage / taxes blush / benefits gold).
//

import SwiftUI

struct MiniDonut: View {
    let takeHome: Double
    let taxes: Double
    let benefits: Double
    var size: CGFloat = 40

    private let goldColor = Color.incGold // mirrors EarningsBreakdownView

    var body: some View {
        let total = max(0.0001, takeHome + taxes + benefits)
        let thickness = size * 0.22
        let radius = (size - thickness) / 2
        let sageEnd = takeHome / total
        let blushEnd = (takeHome + taxes) / total

        ZStack {
            Circle()
                .strokeBorder(Color.incHairline, lineWidth: thickness)
                .frame(width: size, height: size)
            arc(from: 0, to: sageEnd, color: .incSage, radius: radius, thickness: thickness)
            arc(from: sageEnd, to: blushEnd, color: .incBlush, radius: radius, thickness: thickness)
            arc(from: blushEnd, to: 1, color: goldColor, radius: radius, thickness: thickness)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func arc(from start: Double, to end: Double,
                     color: Color, radius: CGFloat, thickness: CGFloat) -> some View {
        if end > start {
            Circle()
                .trim(from: start, to: end)
                .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .frame(width: radius * 2, height: radius * 2)
        }
    }
}
