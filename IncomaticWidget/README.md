# Payday widget — target setup

The target exists, builds, and embeds in the app. One step is left, and it is in
the Apple developer portal rather than here.

## Done already: target, membership, versions

The extension target `IncomaticWidgetExtension` is in `project.pbxproj` with
`PaydayWidget.swift` as its only view source. Six files are shared with the app:

- `incomatic/Payday/PayAnchor.swift`
- `incomatic/Payday/PaydayInfo.swift`
- `incomatic/Payday/PaydayShared.swift`
- `incomatic/Design/DesignTokens.swift`
- `incomatic/Design/CurrencyFormatting.swift`
- `incomatic/Models/CalculatorEnums.swift`

**How that sharing works matters if you ever add a seventh file.** The app target
uses an Xcode 16 synchronized folder group, which auto-enrols everything under
`incomatic/` into the app and offers no way to add a *second* target — its
exception set only subtracts. So the six above are additionally listed as classic
`PBXFileReference`/`PBXBuildFile` entries under a "Shared with Widget" group,
feeding the widget's own Sources phase. Ticking Target Membership in the File
Inspector will not do this for you. Add a new shared file the same way, by hand.

`PaydayShared.swift` was split out of `PaydayStore.swift` for exactly this: the
store is `@MainActor` and `ObservableObject`, which the extension has no use for.
Do **not** add `PaydayStore.swift` or any view file to the extension.

The shared types are declared `nonisolated` on purpose — the app target sets
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and the widget target does not, so
without it the same source compiles under different isolation in each target.
Do not "fix" that by adding the setting to the widget: `TimelineProvider`'s
requirements are nonisolated and would fight it.

## The one step left: App Group

The widget shows an empty state until this is done.

1. developer.apple.com → Certificates, Identifiers & Profiles → Identifiers →
   **App Groups** → register `group.com.makusha.incomatic`.
2. Add the group to **both** App IDs: `com.makusha.incomatic` and
   `com.makusha.incomatic.IncomaticWidget`.
3. Build. Automatic signing picks the change up; the entitlements files for both
   targets are already committed, so there is nothing to tick in Xcode.

The identifier is already in the code as `PaydayShared.appGroupID`. If you use a
different one, change it there and nowhere else.

Until this is done `UserDefaults(suiteName:)` silently falls back to the app's
own defaults, so **the app keeps working and only the widget looks empty**. That
is deliberate, but it also means a missing App Group produces no error to notice
— if the widget renders "Set your payday" while the app shows a countdown, this
step is why.

## Deep link (optional, and not wired)

Tapping the widget opens the app at its last screen. To land on Insights instead,
add `.widgetURL(URL(string: "incomatic://payday"))` to the entry view and handle
`onOpenURL` in `ContentView`. Left out because the app has no URL scheme
registered yet, and adding one is a separate decision.

## Verify

The extension has no unit tests: WidgetKit timeline providers are awkward to test
meaningfully, and the logic that matters is in `PaydayCalculator`, which is
covered by `PaydayCalculatorTests`. Check by hand:

- Long-press the Home Screen → add the **Payday** widget in small and medium.
- With no anchor set: "Add your payday".
- Set one in the app; the widget should update within a few seconds
  (`WidgetCenter.reloadAllTimelines()` fires on save).
- Lock Screen: add the circular and rectangular ones. **The circular must never
  show a dollar figure** — there is no code path for it, and that is the point.

This file is excluded from the shipped `.appex` via `membershipExceptions`;
synchronized groups otherwise sweep unknown file types in as bundle resources.
