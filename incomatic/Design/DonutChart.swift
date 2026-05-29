//
//  
//  DonutChart.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//

import SwiftUI

struct DonutChart: View {
    struct Wedge {
        let value: Double
        let color: Color
    }
    let wedges: [Wedge]
    let centerLabel: String
    let centerValue: String
    var thickness: CGFloat = 22

    private var total: Double { wedges.reduce(0) { $0 + $1.value } }

    private func wedgeRange(_ index: Int) -> (CGFloat, CGFloat) {
        guard total > 0 else { return (0, 0) }
        let before = wedges.prefix(index).reduce(0) { $0 + $1.value }
        return (CGFloat(before / total), CGFloat((before + wedges[index].value) / total))
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(Color.incHairline, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                    .frame(width: size - thickness, height: size - thickness)
                ForEach(Array(wedges.enumerated()), id: \.offset) { idx, w in
                    let range = wedgeRange(idx)
                    Circle()
                        .trim(from: range.0, to: range.1)
                        .stroke(w.color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .frame(width: size - thickness, height: size - thickness)
                }
                VStack(spacing: 4) {
                    Text(centerLabel.uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.incTextMute).kerning(0.6)
                    Text(centerValue)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.incText)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .kerning(-0.5)
                }
                .frame(maxWidth: size * 0.6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
