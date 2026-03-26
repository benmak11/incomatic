# CLAUDE.md — Incomatic Project Context

This file provides context for AI agents working on this codebase.

## Project Overview

**Incomatic** is an iOS app (Swift/SwiftUI) that calculates take-home pay after taxes and deductions. It communicates with a backend API at `localhost:8080`.

## File Structure

```
incomatic/
├── incomaticApp.swift              # App entry point
├── ContentView.swift               # All UI — input form + results display
├── SalaryCalculatorViewModel.swift # ObservableObject; owns isLoading, calculationResult, errorMessage
├── SalaryCalculatorService.swift   # API call to POST /v1/calculate; transforms response to ViewFriendlyResponse
└── LocationManager.swift           # CLLocationManager wrapper; publishes `state` (full name, e.g. "New York")
```

## API Contract

**Do not change the request/response models.** The backend expects:

- `POST /v1/calculate`
- Request body: `SalaryCalculationRequest` (defined in `SalaryCalculatorService.swift`)
  - `country`, `taxYear`, `annualSalary`, `cadence` ("WEEKLY" | "BIWEEKLY" | "MONTHLY" | "ANNUAL")
  - `pretax`: optional `{ pensionPercent, fixed, hsa }`
  - `posttax`: optional `{ fixed, studentLoanPlan }`
  - `countryOptions.US`: `{ state (2-letter code), filingStatus ("SINGLE" | "MARRIED"), allowances }`

**State code conversion** happens in `ContentView.getStateCode(from:)` — `LocationManager` stores full state names, the method maps them to 2-letter codes before building the request.

## Data Models (view layer)

All defined in `SalaryCalculatorService.swift`. Key types:

- `ViewFriendlyResponse` — top-level result; contains `grossPay`, `taxes`, `deductions`, `netPay`
- `GrossPay` — `annual`, `perPayPeriod`, `payFrequency`
- `Taxes` — `federal`, `state`, `local` (`TaxBreakdown?`), `fica` (`FICATaxes`), `totalTaxes`, `effectiveTaxRate`
- `Deductions` — `preTax: [DeductionItem]`, `postTax: [DeductionItem]`, `total`
- `NetPay` — `annual`, `perPayPeriod`, `takeHomePercentage`

## In-Progress: UI Redesign

### Goal
Rebuild `ContentView.swift` to match the provided Figma-style mockups while keeping all existing logic (state management, API call flow, location handling) intact.

### Design Reference (two screens)

**Screen 1 — Dashboard / Monthly Summary ("Financial Clarity.")**
- Dark navy header with "Incomatic" wordmark and circular avatar
- Hero section: "MONTHLY SUMMARY / Financial Clarity." headline + subtitle
- Estimated Net Pay card: large `$X,XXX.XX` amount, trend line chart, `+X.X% from last period` label
- Total Gross card (light blue tint): icon + `$XX,XXX.00` + subtitle (hours of service)
- Tax Withheld card (light blue tint): icon + `$X,XXX.00` + red progress bar + effective rate label
- Deduction Breakdown list: labeled rows with `-$X,XXX.00` amounts; "MATCHED" badge on 401(k); "View Paystub" link
- Smart Insight card (dark teal): lightbulb icon, insight copy, dark CTA button "Apply Strategy"
- Footer teaser: "Plan for the long term." on a muted image
- Bottom tab bar: Home, Chart, Settings icons

**Screen 2 — Input / Revenue Projection ("Define your Financial Horizon.")**
- Light background; avatar + "Incomatic" + hamburger menu in nav bar
- "REVENUE PROJECTION" label + bold headline + subtitle copy
- BASE COMPENSATION section: large `$ 0.00` input field
- FREQUENCY + LOCATION inline pills (segmented / dropdown): "Annual Salary", "New York, NY"
- Tax & Deductions section:
  - 401(k) Contribution row: icon, title, subtitle, editable `%` stepper (shows current %)
  - Healthcare Premium row: icon, title, subtitle, `+` add button
- Instant Precision Reporting card (dark teal): trend icon, heading, copy, `PROJECTED TAKE-HOME $0.00` field, "Calculate Impact" CTA button
- Bottom tab bar: Home (active), Chart, Settings icons

### Implementation Rules
1. All SwiftUI state variables in `ContentView` must remain (`annualSalary`, `selectedPayFrequency`, `selectedFilingStatus`, `allowances`, `pensionPercent`, `hsaContribution`).
2. The `calculateSalary()` function and `canCalculate` guard must not change.
3. `viewModel.calculateSalary(request:)` is the sole async trigger — keep the `Task { }` wrapper.
4. `locationManager.state` drives location display and the state-code lookup; do not bypass it.
5. Results (`ViewFriendlyResponse`) are rendered from the same model fields — only presentation changes.
6. The bottom tab bar is presentational for now (no navigation implemented yet).

## Color Palette (from designs)

| Token | Approximate value |
|---|---|
| Background | `#F0F4F8` (light blue-grey) |
| Card background | `#FFFFFF` |
| Dark navy (header/cards) | `#1A2E44` |
| Teal CTA card | `#2A5C6E` |
| Accent teal | `#2E7D8C` |
| Red (tax bar) | `#D94F4F` |
| Body text | `#1A2E44` |
| Secondary text | `#6B7A8D` |

## Notes

- Location permission prompt happens automatically on launch via `LocationManager.init`.
- `LocationManager.swift` has an uncommitted local modification — check before editing.
- Backend URL is hardcoded as `http://localhost:8080` in `SalaryCalculatorService.swift`.
