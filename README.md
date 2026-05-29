# Incomatic

A US take-home pay calculator for iOS. Enter your earnings, federal and state
withholding details, and pre-tax benefits — Incomatic returns a per-paycheck
breakdown showing exactly how gross pay splits into taxes, benefits, retirement
contributions, and what actually lands in your bank account.

Built with Swift and SwiftUI.

## What it does

Incomatic talks to a companion calculation service and surfaces the result as a
per-paycheck breakdown of:

- **Gross pay** — base salary or hourly earnings, plus bonus and commission
- **Federal income tax** — withholding driven by your W-4 inputs (modern post-2020 or 2019-style)
- **State and local tax** — based on your work state, with county-level handling where it matters
- **FICA** — Social Security and Medicare
- **Pre-tax benefits** — medical, dental, vision, healthcare FSA, dependent care FSA, HSA
- **Retirement contributions** — Traditional 401(k) and Roth 401(k)
- **Net take-home pay** — the number that actually shows up on payday

The app is organized into two tabs:

- **Calculator** — a four-step input flow (Earnings · Federal · State · Benefits)
  with a live per-keystroke projection of net pay as you fill it in.
- **Insights** — a donut chart and itemized summary breaking gross pay into
  taxes, benefits, retirement, and take-home.

## Features

- Eight pay frequencies: daily, weekly, biweekly, semi-monthly, monthly,
  quarterly, semi-annual, annual
- Salary or hourly income, with regular and overtime hours
- Bonus and commission support
- Filing status: Single, Married Filing Jointly, Head of Household
- Full modern W-4 input set: dependents amount, other income, itemized
  deductions, additional withholding, multiple-jobs toggle, plus exemption
  toggles for federal / Social Security / Medicare
- Legacy 2019-style W-4 fallback for jobs that still use it
- Nonresident alien withholding flag
- Automatic state detection via Core Location, with a manual picker fallback
- All 50 states + DC, including Maryland county selection
- Six per-period pre-tax benefit inputs (medical, dental, vision, healthcare
  FSA, dependent care FSA, HSA)
- Traditional and Roth 401(k) percent sliders
- Named custom pre-tax deductions
- "Live in another state" capture for future multi-state withholding splits

## Requirements

- iOS 18.6 or later
- Xcode 26 or later to build
- A running calculation backend (the companion `salary-calculator` service).
  Production deployments are supported; localhost is supported for development.

## Getting started

1. Clone the repo.
2. Bootstrap the local config file:

   ```sh
   cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
   ```

   Open `Config/Secrets.xcconfig` and fill in the backend URL for your
   deployment. (The committed example contains a placeholder.)
3. Open `incomatic.xcodeproj` in Xcode.
4. Build and run on a simulator or device.

On launch the app will request location permission so it can pre-fill your
work state.

## Project layout

```
incomatic/
├── incomaticApp.swift              # App entry point
├── ContentView.swift               # Tab bar + Calculator + Insights UI
├── AppConfig.swift                 # Resolves prod vs. localhost backend URL
├── SalaryCalculatorService.swift   # REST client for the calculation backend
├── SalaryCalculatorViewModel.swift # @MainActor ObservableObject for the UI
└── LocationManager.swift           # Core Location wrapper

Config/                             # Project-level config, not bundled into the app
├── Info.plist                      # Uses $(API_BASE_URL_PROD) substitution
├── Secrets.xcconfig                # Gitignored — your backend URL lives here
└── Secrets.xcconfig.example        # Committed template
```

## Tech

- Swift / SwiftUI
- Core Location for automatic state detection
- `async`/`await` `URLSession` against a JSON REST backend
- xcconfig + checked-in `Info.plist` with build-time variable substitution for
  configurable backend URLs
