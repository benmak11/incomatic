//
//  TaxYearRefresh.swift
//  incomatic
//
//  Created by Ben Makusha on 08/04/2026
//
//  Keeps AppConfig.taxYear pointed at the newest rule pack the backend has
//  published, so a new tax year takes effect without an app update.
//

import Foundation

/// Refreshes the cached tax year from `GET /v1/tax-years`.
///
/// Silent on failure by design, mirroring `loadUSStates()`: the previously
/// cached year (or `AppConfig.fallbackTaxYear` on a first launch) stays in use,
/// so a flaky connection degrades to a slightly stale year rather than a
/// blocked launch. Calculations remain correct either way, because the backend
/// only ever advertises years it can actually serve.
func refreshTaxYear() async {
    do {
        let years = try await SalaryCalculatorService().fetchTaxYears()
        if let latest = years.defaultTaxYear {
            AppConfig.cacheTaxYear(latest)
        }
    } catch {
        // Keep whatever we already had.
    }
}
