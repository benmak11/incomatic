//
//  
//  IncCard.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//

import SwiftUI

struct IncCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.incSurface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 22, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
}
