//
//
//  IncTopBar.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//

import SwiftUI

struct IncTopBar<Trailing: View>: View {
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.incSage)
                    .frame(width: 34, height: 34)
                    .shadow(color: Color.incSage.opacity(0.3), radius: 6, x: 0, y: 2)
                Text("i")
                    .italic()
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(.white)
            }
            Text("Incomatic")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.incText)
                .kerning(-0.4)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

extension IncTopBar where Trailing == EmptyView {
    init() {
        self.init(trailing: { EmptyView() })
    }
}
