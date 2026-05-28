# Incomatic — Claude Notes

iOS app (Swift/SwiftUI) that calculates US take-home pay. Calls the salary-calculator
backend at `http://localhost:8080`. This file tracks the current state of the codebase
and the UI redesign history.

## File structure

```
incomatic/
├── incomaticApp.swift              # App entry point — untouched across the redesign
├── ContentView.swift               # All UI: tab bar + Calculator + Insights
├── SalaryCalculatorViewModel.swift # @MainActor ObservableObject; isLoading, calculationResult, errorMessage
├── SalaryCalculatorService.swift   # POST /v1/calculate; GET /v1/countries/US/states; transforms to ViewFriendlyResponse
└── LocationManager.swift           # CLLocationManager wrapper; publishes `state` (full name, e.g. "New York")
```

## UI redesign history (2026)

The Calculator + Insights flow has been rebuilt across several passes during the ADP-parity
migration on the backend side. Each pass is summarized below.

### Pass 1 — 4-segment Calculator (ADP-parity, foundation)

Restructured `CalculatorTab` from a single scrollable form to a 4-segment picker matching
ADP's input model: **Earnings · Federal · State · Benefits**. Each segment owns its own
card stack; one shared "Calculate" button at the bottom.

Concrete changes:
- `PayFrequency` enum extended to 8 cases (daily, weekly, biweekly, semi-monthly, monthly,
  quarterly, semi-annual, annual) with a `periodsPerYear: Double` helper.
- New enums: `CalculatorSection`, `IncomeType` (salary/hourly), `SalaryBasis` (perYear/perPeriod).
- **Earnings** section: pay frequency, salary/hourly toggle (with rate + regular hours +
  overtime hours), bonus + commission, pay date.
- **Federal** section: filing status (Single / Married jointly / Head of Household — sent
  verbatim, no more HoH→SINGLE fallback), 2019 W-4 toggle, nonresident-alien toggle, multiple
  jobs toggle, dependents amount, other income, itemized deductions, additional withholding,
  three exemption toggles (federal / SS / Medicare).
- **State** section: state picker driven by `GET /v1/countries/US/states` (with hardcoded
  50-state fallback), "do you live in another state" multi-state flow, MD-county dropdown
  (only when state == MD).
- **Benefits** section: 6 per-period pre-tax fields (medical, dental, vision, healthcare FSA,
  dependent care FSA, HSA), Traditional 401(k) slider, Roth 401(k) slider, custom deductions list.

### Pass 2 — Insights donut + itemized right-rail

Replaced the 3-bar mini chart with a single donut (Take Home / Taxes / Benefits) and an
ADP-style itemized summary keyed off the new `LineItem.category` field.

Concrete changes:
- New `DonutChart` view (SwiftUI `Circle().trim` arcs with center label) — single hero visual.
- New itemized summary card with section headers (Earnings / Taxes / Benefits / Take Home),
  driven by switching on `lineItem.category` rather than name-pattern matching.
- `ViewFriendlyResponse` exposes raw `lineItems: [LineItem]` so the Insights view can filter
  by category.

### Pass 3 — Sage palette + Step indicator + Sticky progressive CTA

Drop-in `ContentView.swift` rewrite from the design handoff. Major changes:
- **Bottom tab bar reduced 4 → 2 tabs**: Calculator + Insights only. The `BenefitsTab` struct
  is removed (those inputs already live inside the Calculator's Benefits section); the
  `SettingsTab` struct is removed (returns when account/auth lands).
- **Sage palette**: `incBg #F5F1EA`, `incSage #5F8C7C`, `incSageBg`, `incSageSoft`, `incBlush`,
  etc. replace the prior teal/navy tokens.
- **`IncTopBar`**: wordmark only (sage `i` monogram + "incomatic"). No search button, no avatar.
  Rendered inline at the top of each tab's ScrollView; no `NavigationView` toolbar.
- **`SectionStepIndicator`**: four numbered circles connected by a 1.5px progress line that
  fills with sage as the user advances. Completed steps show a checkmark in `incSageSoft`.
  Replaces the segmented `Picker`.
- **`StickyProgressCTA`**: sticky overlay above the tab bar with two stacked surfaces — a
  sage-tinted projection ribbon (`livePreviewPerPeriod` + `% of gross`, computed client-side
  per keystroke) and a button row. On Earnings/Federal/State the primary button is
  `Continue to <next>` with a `Skip to calc` escape; on Benefits the primary is
  `Calculate detailed projection` and the escape disappears.
- **Insights `.refreshable`** pull-to-refresh added (placeholder; hook for future
  `GET /v1/calculations/{id}/refresh`).
- **Section transitions** wrapped in `withAnimation(.easeInOut(0.35))` with `.id(activeSection)`
  for a fade + slight Y-offset re-mount.
- **Keyboard dismissal**: `scrollDismissesKeyboard(.interactively)` on the Calculator scroll.

### Pass 4 — Spacing fix (Group → VStack)

The Pass-3 drop-in had a layout bug: the section content was wrapped in
`Group { switch activeSection { … } }.padding(.bottom, 230)`. `Group` is a transparent
container whose modifiers propagate to every member, so the 230px bottom padding was being
applied to *each card* instead of the bottom of the stack — resulting in 244px of empty
space below every card (14px built-in + 230px from the Group). Wrapping the switch in
`VStack(spacing: 0)` makes the padding apply once.

## Current design tokens (sage palette)

All defined as `private extension Color` at the top of `ContentView.swift`.

| Token              | Hex      | Use                                          |
|--------------------|----------|----------------------------------------------|
| `incBg`            | `#F5F1EA` | App background (warm cream)                 |
| `incSurface`       | `#FFFFFF` | Card background                              |
| `incText`          | `#1F2A2A` | Primary text, headlines                      |
| `incTextDim`       | `#5A6868` | Body & secondary text                        |
| `incTextMute`      | `#94A09E` | Labels, placeholders, inactive states        |
| `incSage`          | `#5F8C7C` | Primary accent — CTA, active step, focus     |
| `incSageDeep`      | `#3F6B5C` | Live projection numerals, sage hover         |
| `incSageSoft`      | `#D7E4DE` | Completed step background, secondary border |
| `incSageBg`        | `#EEF5F1` | Sage tint surfaces (icon badges, ribbon bg)  |
| `incBlush`         | `#E89B7D` | Informational accent (rule-pack callout)     |
| `incBlushBg`       | `#FBE9DE` | Informational surface                        |
| `incHairline`      | `rgba(31,42,42,0.08)` | 1px field underline, dividers          |
| `incHairlineStrong`| `rgba(31,42,42,0.14)` | 1.5px borders, radio default            |
| `incRed`           | `#D93B3B` | Destructive (sign-out, errors)               |

**Type**: system fonts (SF Pro). Key sizes are inline in the code. Page headline is
36pt bold with -1 kerning; card title 15pt bold; field label 11pt bold uppercased with
0.8 kerning; money input 22pt semibold.

**Radii**: cards 22, sticky CTA 22, primary/secondary buttons 14, icon badges 12,
toggle pill 13.

**Shadows**: card = `radius 22 y 6 black/0.04` + `radius 2 y 1 black/0.02`;
sticky CTA = `radius 24 y 6 black/0.10` + `radius 2 y 1 black/0.03`.

## API contract (current — post ADP-parity)

`SalaryCalculatorService.SalaryCalculationRequest` shape sent to `POST /v1/calculate`:

```
country: "US"
taxYear: 2025
annualSalary: Double?           # legacy fallback; nil when `earnings` is set
bonus: Double?                  # legacy shim
earnings: Earnings?             # preferred — { salary, hourly, bonus, commission }
payDate: String?                # ISO yyyy-MM-dd
cadence: String                 # DAILY | WEEKLY | BIWEEKLY | SEMIMONTHLY | MONTHLY | QUARTERLY | SEMIANNUAL | ANNUAL
pretax: PreTaxDeductions?       # { pensionPercent, fixed, hsa, medical, dental, vision, healthcareFsa, dependentCareFsa }
posttax: PostTaxDeductions?     # { fixed, roth401kPercent, studentLoanPlan }
countryOptions.US: USOptions    # { state (2-letter), filingStatus, allowances, w4 }
countryOptions.US.w4: W4?       # { useOldW4, nonresidentAlien, dependentsAmount, otherIncome,
                                #   itemizedDeductions, additionalWithholding, exemptFederal,
                                #   exemptSocialSecurity, exemptMedicare }
```

Response: `SalaryCalculationResponse` with `lineItems: [LineItem]` where each `LineItem` has
`name`, `amount`, and an optional `category` string. Categories the backend emits:
`EARNINGS`, `TAX_FEDERAL`, `TAX_FICA`, `TAX_STATE`, `PRE_TAX_BENEFIT`, `RETIREMENT`,
`POST_TAX`, `NET`. The Insights donut + summary filters on these.

`ViewFriendlyResponse` (the transformed shape consumed by the UI) carries the raw
`lineItems` list through to the Insights view.

`GET /v1/countries/US/states` returns a direct JSON array `[{ "code": "CA", "name": "California" }, …]`.
The Calculator's State section drives its picker from this endpoint, with a hardcoded
51-entry fallback if the call fails.

## State-management rules (do not break)

- All `@State` form variables in `CalculatorTab` are owned by the tab itself and survive
  across section switches.
- `triggerCalculation()` is the only place that builds the request. Do not duplicate this
  logic elsewhere.
- `canCalculate` guard: at least one of (salary, hourly, bonus, commission) is > 0 AND
  `selectedStateCode` is non-empty.
- `loadStatesFromApi()` runs once on `.task`; failures fall back silently to
  `CalculatorTab.fallbackStates`.
- `LocationManager.state` drives `selectedStateCode` via the existing `.onChange` hook —
  the location name is matched against `statesList.name` and the 2-letter code is set.
- Auto-route to Insights tab on successful calculation lives in `ContentView` as
  `.onChange(of: viewModel.isLoading)` — when loading flips from true to false and a result
  is present, `selectedTab = 1`.

## Known follow-ups (not yet implemented)

- `POST /v1/reports/pdf` — Insights "Download PDF report" still shows a "Coming Soon" alert.
- `GET /v1/insights/{calculationId}` — Insights 401(k) Smart Saving copy is still a
  client-side estimate (1% of gross / 12, with assumed 100% employer match capped at 6%).
  Replace with backend-computed insights once the endpoint exists.
- `GET /v1/calculations/{id}/refresh` — the Insights `.refreshable { … }` currently just
  sleeps 700ms as a placeholder. Wire to the real endpoint when it lands.
- Multi-state withholding split — the State section captures the "do you live in another
  state" flag, secondary state, and non-residency-certificate toggle, but the backend does
  not yet compute a split. The work-state's rates are applied.
- Modern W-4 "multiple jobs" adjustment — the toggle is stored but not yet sent to the
  backend (per the scope decision in salary-calculator/CLAUDE.md).
- Auth + Settings + Benefits tabs — removed in Pass 3; will return when those features land.

## Notes

- Backend URL is hardcoded `http://localhost:8080` in `SalaryCalculatorService.swift`.
- Location permission prompt happens automatically on launch via `LocationManager.init`.
- The Insights view uses string comparisons against the backend's `category` field (e.g.
  `"TAX_FEDERAL"`) rather than a Swift enum — the field is decoded as `String?` and may be
  nil for legacy / informational line items (e.g. UK "Tax-Free Allowance").
