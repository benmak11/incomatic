//
//
//  PaydayNotificationScheduler.swift
//  incomatic
//
//  Created by Ben Makusha on 08/14/2026
//
//  Scheduled locally rather than pushed. No server dependency, no delivery gap
//  if the backend is down, and no need to ship pay dates off the device.
//

import Foundation
import UserNotifications

enum PaydayNotificationScheduler {

    /// One pending request at a time. Rescheduling replaces it rather than
    /// stacking, so an anchor edited five times does not deliver five alerts.
    static let requestID = "incomatic.payday.next"

    /// 8am on the day. Deposits post overnight, so the figure is real by then,
    /// and it lands with the morning phone check before the money is spent.
    private static let hour = 8

    // MARK: - Permission

    /// Asks the system. Only ever called after the user taps the affirmative in
    /// our own priming sheet, so a decline here costs nothing that was not
    /// already declined in a surface we control.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Replaces the pending request with one for the next payday.
    ///
    /// Safe to call unconditionally: it cancels when there is no anchor, and
    /// does nothing when permission was never granted, so callers do not have to
    /// remember the preconditions.
    static func reschedule(anchor: PayAnchor?, net: Double) {
        Task { await rescheduleAsync(anchor: anchor, net: net) }
    }

    static func rescheduleAsync(anchor: PayAnchor?, net: Double) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])

        guard let anchor,
              let info = PaydayCalculator.info(for: anchor, net: net) else { return }
        guard await authorizationStatus() == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Incomatic"
        content.body = body(for: info)
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: info.date)
        components.hour = hour
        components.minute = 0

        // Non-repeating on purpose. A repeating trigger cannot express "the 15th
        // and the last day", and an interval schedule drifts against weekend
        // shifting. Each delivery reschedules the next one instead.
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// The body states the amount.
    ///
    /// Withholding it buys one open and teaches the user the alert is bait, so
    /// it is the first thing muted once novelty passes. Stating it makes the
    /// notification useful on its own, which is what keeps it unmuted long
    /// enough for the habit to form.
    static func body(for info: PaydayInfo) -> String {
        guard info.hasNet else {
            // No figure has ever been calculated on this install, so the alert
            // states the day and nothing else rather than announcing "$0".
            return info.approximate
                ? "Payday should be about today."
                : "Payday is today. Tap to work out where it goes."
        }
        let amount = formatCurrency(info.net)
        if info.approximate {
            return "Payday should be about today. \(amount) expected."
        }
        return "\(amount) lands today. Tap to see where it goes."
    }
}
