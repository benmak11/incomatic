//
//
//  DesignTokens.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Sage palette tokens used across all views.
//
//  Every token is system-adaptive: it resolves to the light value in light
//  mode and the dark value in dark mode, driven by the device's
//  userInterfaceStyle. Values mirror inc-theme.css from the Claude Design
//  project (light + dark token sets). Dark mode is true iOS graphite —
//  #000 grouped base, #1C1C1E elevated cards, brightened sage accent.
//

import SwiftUI
import UIKit

private extension UIColor {
    /// Build a UIColor from a 0xRRGGBB literal (+ optional alpha).
    convenience init(rgb hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue:  CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// A color that resolves to `light` in light mode and `dark` in dark mode.
private func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

extension Color {
    // surfaces
    static let incBg              = adaptive(UIColor(rgb: 0xF5F1EA), UIColor(rgb: 0x000000))
    static let incSurface         = adaptive(UIColor(rgb: 0xFFFFFF), UIColor(rgb: 0x1C1C1E))
    // text
    static let incText            = adaptive(UIColor(rgb: 0x1F2A2A), UIColor(rgb: 0xFFFFFF))
    static let incTextDim         = adaptive(UIColor(rgb: 0x5A6868), UIColor(rgb: 0xEBEBF5, alpha: 0.60))
    static let incTextMute        = adaptive(UIColor(rgb: 0x94A09E), UIColor(rgb: 0xEBEBF5, alpha: 0.42))
    // accent — sage (brightened on dark for contrast)
    static let incSage            = adaptive(UIColor(rgb: 0x5F8C7C), UIColor(rgb: 0x7FB29F))
    static let incSageDeep        = adaptive(UIColor(rgb: 0x3F6B5C), UIColor(rgb: 0xA6D8C5))
    static let incSageSoft        = adaptive(UIColor(rgb: 0xD7E4DE), UIColor(rgb: 0x7FB29F, alpha: 0.40))
    static let incSageBg          = adaptive(UIColor(rgb: 0xEEF5F1), UIColor(rgb: 0x7FB29F, alpha: 0.15))
    // secondary accents
    static let incBlush           = adaptive(UIColor(rgb: 0xE89B7D), UIColor(rgb: 0xEBA890))
    static let incBlushBg         = adaptive(UIColor(rgb: 0xFBE9DE), UIColor(rgb: 0xE89B7D, alpha: 0.15))
    static let incGold            = adaptive(UIColor(rgb: 0xE4C77A), UIColor(rgb: 0xE8CF86))
    static let incRed             = adaptive(UIColor(rgb: 0xD93A3A), UIColor(rgb: 0xFF6961))
    // lines
    static let incHairline        = adaptive(UIColor(rgb: 0x1F2A2A, alpha: 0.08), UIColor(rgb: 0xFFFFFF, alpha: 0.09))
    static let incHairlineStrong  = adaptive(UIColor(rgb: 0x1F2A2A, alpha: 0.14), UIColor(rgb: 0xFFFFFF, alpha: 0.18))
    static let incCardBorder      = adaptive(UIColor(rgb: 0xFFFFFF, alpha: 0.00), UIColor(rgb: 0xFFFFFF, alpha: 0.07))
    // controls
    static let incDisabled        = adaptive(UIColor(rgb: 0xC4CCCA), UIColor(rgb: 0x2C2C2E))
    static let incBtnSolid        = adaptive(UIColor(rgb: 0x1F2A2A), UIColor(rgb: 0x2C2C2E))
    static let incBtnSolidText    = adaptive(UIColor(rgb: 0xFFFFFF), UIColor(rgb: 0xFFFFFF))
}
