//
//  SubscriptionRequired.swift
//  incomatic
//
//  Created by Ben Makusha on 08/06/2026
//
//  The client half of the backend's 402. Ships dark: the backend's
//  SUBSCRIPTION_ENFORCEMENT flag is off, so nothing returns 402 yet.
//

import Foundation

/// Thrown when the backend refuses a Pro-only route with **402 Payment Required**.
///
/// A distinct type rather than another `server(402, …)` case, because the two
/// need opposite handling: a server error is a failure to report, while this is
/// a product state to present. Carrying `feature` lets the paywall open on the
/// surface that was actually refused instead of a generic upgrade page.
///
/// 402 rather than 403 is the backend's deliberate choice — 403 would be
/// indistinguishable from a permissions problem.
struct SubscriptionRequired: LocalizedError, Equatable {
    /// Backend feature key, e.g. `budget_plan`. Empty when the payload omitted it.
    let feature: String

    var errorDescription: String? {
        "This feature is part of Incomatic Pro."
    }

    /// Reads the backend's `{"error":"subscription_required","feature":"…"}`.
    ///
    /// A 402 with an unreadable body still refuses, just without knowing which
    /// surface to open. Failing to parse must not turn a refusal into a success.
    static func from(_ data: Data) -> SubscriptionRequired {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let feature = json["feature"] as? String
        else {
            return SubscriptionRequired(feature: "")
        }
        return SubscriptionRequired(feature: feature)
    }
}
