//
//  BudgetVisuals.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  View-layer icon/color mapping for the Budget enums. Kept out of
//  BudgetModels.swift so that file stays pure Foundation (it's also the
//  Codable/network shape) — same separation CalculatorEnums.swift keeps from
//  its own views (displayName lives on the enum, colors/icons don't).
//

import SwiftUI

extension GoalType {
    var icon: String {
        switch self {
        case .emergencyFund:   return "shield.fill"
        case .vacation:        return "beach.umbrella.fill"
        case .homeDownPayment: return "house.fill"
        case .debtPayoff:      return "chart.line.downtrend.xyaxis"
        case .car:              return "car.fill"
        case .wedding:          return "heart.fill"
        case .custom:            return "star.fill"
        }
    }
}

extension BudgetBucket {
    var color: Color {
        switch self {
        case .needs:   return .incSageDeep
        case .wants:   return .incBlush
        case .savings: return .incGold
        }
    }
}

/// The circular chevron used to leave any budget screen. One definition, so the
/// setup steps and the finished shell cannot drift apart visually.
///
/// `BudgetFlowView` is presented as a `fullScreenCover`, which has no swipe to
/// dismiss and no system back. Every step therefore has to draw its own way out,
/// or the user is stuck - which is exactly the bug this was extracted to fix.
struct BudgetBackButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.incTextDim)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.incSurface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
