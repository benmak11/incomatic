//
//  ScrollDirectionReporting.swift
//  incomatic
//
//  Created by Ben Makusha on 07/21/2026
//
//  Shared scroll-direction detector so every scrollable top-level screen can
//  drive the shell's floating pill nav the same way: shrink while scrolling
//  down, expand near the top or when scrolling back up. Mirrors the logic
//  CalculatorTab pioneered, factored out so Insights/History match it exactly
//  instead of drifting out of sync.
//

import SwiftUI

extension View {
    func reportingScrollDirection(_ onChange: @escaping (Bool) -> Void) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { geo in
            let scrollable = geo.contentSize.height - geo.containerSize.height
            guard scrollable > 0 else { return 0 }
            let offsetY = geo.contentOffset.y + geo.contentInsets.top
            return min(max(offsetY / scrollable, 0), 1)
        } action: { old, progress in
            if progress <= 0.02 {
                onChange(false)   // back at the top — always expanded
            } else if progress > old + 0.004 {
                onChange(true)    // scrolling down — shrink
            } else if progress < old - 0.004 {
                onChange(false)   // scrolling up — expand
            }
        }
    }
}
