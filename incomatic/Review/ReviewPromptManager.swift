//
//  ReviewPromptManager.swift
//  incomatic
//
//  Created by Ben Makusha on 08/03/2026
//
//  Fire-once trigger for the App Store rating prompt. Backed directly by
//  UserDefaults.standard (not @AppStorage) so it's callable from the
//  ContentView.onChange success path without a View context.
//

import Foundation

nonisolated enum ReviewPromptManager {
    private static let successfulCalculationCountKey = "incomatic.successfulCalculationCount"
    private static let hasPromptedForReviewKey = "incomatic.hasPromptedForReview"

    /// Number of successful calculations recorded so far.
    private static var successfulCalculationCount: Int {
        get { UserDefaults.standard.integer(forKey: successfulCalculationCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: successfulCalculationCountKey) }
    }

    /// True once the review prompt has fired. Set once and never cleared.
    private static var hasPromptedForReview: Bool {
        get { UserDefaults.standard.bool(forKey: hasPromptedForReviewKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasPromptedForReviewKey) }
    }

    /// Call once per successful calculation. Increments the running count and
    /// returns true exactly once — on the calculation where the count first
    /// reaches 3 — signaling the caller to trigger the native review prompt.
    /// Fire-once: subsequent calculations (4th, 5th, ...) always return false.
    @discardableResult
    static func recordSuccessfulCalculation() -> Bool {
        successfulCalculationCount += 1
        if successfulCalculationCount == 3 && !hasPromptedForReview {
            hasPromptedForReview = true
            return true
        }
        return false
    }
}
