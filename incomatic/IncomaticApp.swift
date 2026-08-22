//
//  IncomaticApp.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//

import SwiftUI
import UserNotifications

@main
struct IncomaticApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Exists for one reason: notification delivery has no SwiftUI equivalent.
///
/// The delegate has to be attached before the system hands over a launch
/// notification, and `didFinishLaunching` is the only point guaranteed to be
/// early enough. Setting it from a view's `onAppear` or `task` compiles and
/// looks right, but silently misses the cold-launch tap — which is the exact
/// case the payday loop is measured on, since the notification fires at 8am
/// when the app is not running.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = PaydayNotificationDelegate.shared
        return true
    }
}

/// Attributes an app open back to the payday notification, and stops the
/// notification being swallowed when it arrives while the app is already open.
final class PaydayNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PaydayNotificationDelegate()

    /// Without this, iOS suppresses a notification that arrives in the
    /// foreground. Payday fires at 8am, which is exactly when someone might
    /// already be in the app, and silently dropping it there would make the
    /// loop look unreliable for the users who use it most.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Only our payday request counts. Anything else opening the app is not
        // the loop working, and attributing it would flatter the metric that
        // decides whether Phase 2 goes ahead.
        guard response.notification.request.identifier == PaydayNotificationScheduler.requestID else {
            return
        }
        await MainActor.run { PaydayAnalytics.opened(from: .notification) }
    }
}
