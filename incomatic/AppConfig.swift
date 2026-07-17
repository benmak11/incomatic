//
//  AppConfig.swift
//  incomatic
//
//
//  Created by Ben Makusha on 05/28/2026
//
//  Single source of truth for runtime configuration values that vary
//  between environments. Production values are injected at build time
//  via Config/Secrets.xcconfig → INFOPLIST_KEY_APIBaseURLProd.
//

import Foundation

nonisolated enum AppConfig {
    /// Tax year every calculation runs against. Single source of truth for the
    /// request builder, the bonus payout-date captions, and the earnings outlook.
    static let taxYear = 2025

    /// Loopback URL used when running the salary-calculator backend locally.
    static let localBaseURL = "http://localhost:8080"

    /// Active backend base URL. Returns the local override when enabled in
    /// DEBUG builds, otherwise the production URL injected from the bundle.
    static var apiBaseURL: String {
        #if DEBUG
        if useLocalBackend { return localBaseURL }
        #endif
        return prodBaseURL
    }

    /// Production URL read from the generated Info.plist. Empty string if
    /// Secrets.xcconfig is missing — surfaces as an invalid-URL error on
    /// the first network call rather than failing silently.
    static var prodBaseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "APIBaseURLProd") as? String) ?? ""
    }

    #if DEBUG
    private static let useLocalDefaultsKey = "incomatic.useLocalBackend"
    private static let useLocalEnvVar = "INCOMATIC_USE_LOCAL"

    /// True when the local backend should be used. Reads UserDefaults first
    /// (toggleable at runtime) and falls back to the scheme env var so a
    /// fresh launch with the env var set picks up local automatically.
    static var useLocalBackend: Bool {
        get {
            if UserDefaults.standard.object(forKey: useLocalDefaultsKey) != nil {
                return UserDefaults.standard.bool(forKey: useLocalDefaultsKey)
            }
            return ProcessInfo.processInfo.environment[useLocalEnvVar] == "1"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useLocalDefaultsKey)
        }
    }
    #endif
}
