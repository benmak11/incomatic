# Incomatic

A US take-home pay calculator for iOS. Enter your earnings, federal and state
withholding details, and pre-tax benefits — Incomatic returns a per-paycheck
breakdown showing exactly how gross pay splits into taxes, benefits, retirement
contributions, and what actually lands in your bank account. Sign in with
Apple to save calculation history, track RSU grants, and get an AI-generated
household budget plan.

Built with Swift and SwiftUI, talking to the companion `salary-calculator`
Javalin backend (sibling repo).

## What it does

Incomatic talks to a companion calculation service and surfaces the result as a
per-paycheck breakdown of:

- **Gross pay** — base salary or hourly earnings, plus bonus, commission, and RSU vesting
- **Federal income tax** — withholding driven by your W-4 inputs (modern post-2020 or legacy pre-2020 allowances-based)
- **State and local tax** — based on your work state, with county-level handling where it matters (e.g. Maryland)
- **FICA** — Social Security and Medicare
- **Pre-tax benefits** — medical, dental, vision, healthcare FSA, dependent care FSA, HSA
- **Retirement contributions** — Traditional 401(k) (pre-tax) and Roth 401(k) (post-tax, computed on regular wages only)
- **Supplemental income** — bonus (dated, optionally recurring), commission, and RSU vesting, broken out with their own flat-rate federal/FICA withholding
- **Net take-home pay** — the number that actually shows up on payday

The app is organized around a floating pill-nav switching three sections:

- **Calculator** — a four-step guided input flow (Earnings · Federal · State · Benefits)
  with a live per-keystroke projection of net pay as you fill it in.
- **Insights** — a donut chart and itemized summary breaking gross pay into
  taxes, benefits, retirement, and take-home, plus a yearly outlook (future
  RSU vests, projected bonus timing) and the entry point into AI budgeting.
- **History** — saved past calculations (auth required), with full
  request/response detail per session.

First-run users go through a **Guided Notebook onboarding** flow instead of
landing straight on the Calculator, collecting the same inputs conversationally.

## Features

- Eight pay frequencies: daily, weekly, biweekly, semi-monthly, monthly,
  quarterly, semi-annual, annual
- Salary or hourly income, with regular and overtime hours
- Bonus (with payout date and recurring toggle), commission, and RSU vesting income
- Filing status: Single, Married Filing Jointly, Head of Household
- Full modern W-4 input set: dependents amount, other income, itemized
  deductions, additional withholding, plus exemption toggles for
  federal / Social Security / Medicare
- Legacy pre-2020 W-4 (allowances-based) fallback
- Automatic state detection via Core Location, with a manual picker fallback
- All 50 states + DC, including Maryland county selection
- Six per-period pre-tax benefit inputs (medical, dental, vision, healthcare
  FSA, dependent care FSA, HSA)
- Traditional and Roth 401(k) percent sliders — Roth is correctly post-tax,
  applied only to regular wages
- Named custom pre-tax deductions
- **Sign in with Apple** — session persisted in the Keychain; unlocks:
  - **Calculation history** — every saved calc with full detail
  - **RSU grant tracking** — grant terms, vesting schedule, live stock quotes
    (via a Finnhub proxy on the backend) feeding the yearly outlook
  - **AI-generated household budget** — savings goals + itemized expenses →
    a Gemini-generated per-goal contribution strategy, verified against a
    deterministic on-device engine that also serves as the fallback when the
    AI service is unavailable. Gated behind an explicit consent step before
    any financial data leaves the device.
- Account deletion purges history, grants, and budget server-side

## Requirements

- iOS 18.6 or later (built against the iOS 26 SDK)
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
4. Build and run on a simulator or device:
   ```sh
   xcodebuild -scheme incomatic -destination 'generic/platform=iOS Simulator' -configuration Debug build
   ```
   or just Cmd+R in Xcode.

On launch the app will request location permission so it can pre-fill your
work state, and (for RSU/budget/history) offer Sign in with Apple.

## Project layout

```
incomatic/
├── IncomaticApp.swift               # App entry point
├── LaunchView.swift                 # Splash/launch screen
├── ContentView.swift                # Root shell: onboarding gate, pill nav, routing
├── AppConfig.swift                  # Resolves prod vs. localhost backend URL
├── SalaryCalculatorService.swift    # REST client for the calculation backend
├── SalaryCalculatorViewModel.swift  # @MainActor ObservableObject for the calculate flow
├── LocationManager.swift            # Core Location wrapper
│
├── Calculator/                      # Guided input flow (Earnings/Federal/State/Benefits)
├── Insights/                        # Result breakdown, donut chart, yearly outlook
├── Onboarding/                      # First-run Guided Notebook flow
├── History/                         # Saved calculation history (auth required)
├── Account/                         # Sign in with Apple, session, account UI
├── Equity/                          # RSU grant tracking, vesting math, stock quotes
├── Budget/                          # AI budgeting: goals/expenses UI, on-device engine, plan flow
├── Navigation/                      # Floating pill nav, scroll-direction reporting
├── Design/                          # Design tokens, shared field/card components
└── Models/                          # Shared enums (pay cadence, filing status, etc.)

incomaticTests/                      # Unit tests (Swift Testing), e.g. BudgetEngineTests

Config/                              # Project-level config, not bundled into the app
├── Base.xcconfig                    # Shared build settings
├── Info.plist                       # Uses $(API_BASE_URL_PROD) substitution
├── Secrets.xcconfig                 # Gitignored — your backend URL lives here
└── Secrets.xcconfig.example         # Committed template
```

## Tech

- Swift / SwiftUI, `@MainActor` view models, `async`/`await` `URLSession` against a JSON REST backend
- Core Location for automatic state detection
- Sign in with Apple (`AuthenticationServices`) + Keychain-persisted session
- xcconfig + checked-in `Info.plist` with build-time variable substitution for
  configurable backend URLs
- `PBXFileSystemSynchronizedRootGroup` project format (Xcode 15+) — new files
  under `incomatic/` are picked up automatically, no `project.pbxproj` edits needed
