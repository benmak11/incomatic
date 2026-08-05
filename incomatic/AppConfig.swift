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
    private static let taxYearKey = "incomatic.taxYear"

    /// Newest tax year known to exist when this build shipped, used until the
    /// backend's supported-years list has been fetched at least once.
    ///
    /// Deliberately *not* derived from the current date. The backend throws when
    /// asked for a year it has no rule pack for, so rolling forward on January 1
    /// would break every calculation until that year's pack was published.
    /// Erring backwards costs one stale year; erring forwards costs the app.
    static let fallbackTaxYear = 2026

    /// Tax year every calculation runs against. Single source of truth for the
    /// request builder, the bonus payout-date captions, and the earnings outlook.
    ///
    /// Resolved from the backend's `defaultTaxYear` (see `refreshTaxYear()`) and
    /// cached across launches, so a newly published rule pack takes effect
    /// without shipping an app update. Read synchronously because most callers
    /// are SwiftUI view bodies and pure value math; the refresh happens once at
    /// launch and the value is stable for the session.
    static var taxYear: Int {
        let cached = UserDefaults.standard.integer(forKey: taxYearKey)
        return cached > 0 ? cached : fallbackTaxYear
    }

    /// Stores the backend's newest supported tax year. Ignores non-positive
    /// values so a malformed payload can't wipe a good cached year.
    static func cacheTaxYear(_ year: Int) {
        guard year > 0 else { return }
        UserDefaults.standard.set(year, forKey: taxYearKey)
    }

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
