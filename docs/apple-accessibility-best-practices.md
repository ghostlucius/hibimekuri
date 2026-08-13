# Apple Accessibility & Inclusion — Reference for Audit

This document exists to give an auditing agent (or a human) a concrete, checkable
standard for Hibimekuri's accessibility. Every section is sourced directly from
Apple's own documentation/HIG (linked), scoped to what actually applies to this
project: a **macOS-only SwiftUI app** with one piece of real AppKit interop
(`AppKitTaskTable`, a raw `NSTableView` wrapper used for drag-and-drop task reordering
— see `Sources/Hibimekuri/Views/AppKitTaskTable.swift`). iOS/iPadOS/tvOS/watchOS/
visionOS-specific guidance (gestures, Assistive Access, Apple Watch control sizes,
etc.) does not apply here and should not be flagged.

## 1. Vision

Source: [Accessibility (HIG)](https://developer.apple.com/design/human-interface-guidelines/accessibility)

- **Dynamic Type**: macOS's default/minimum system type sizes are **13pt default /
  10pt minimum**. If the app hardcodes font sizes (`.font(.system(size: N))`) instead
  of using semantic text styles or `@ScaledMetric`, none of that text respects the
  system's "larger text" accessibility setting at all. This is worth auditing
  specifically — most of this app's text (`DS.smallCaption`, the numeral, almanac
  labels, task rows) uses fixed-point `.system(size:)` fonts, which is a real
  candidate for "doesn't support Dynamic Type."
- **Color contrast**: macOS WCAG AA minimums Apple's own Accessibility Inspector
  checks against: **4.5:1** for text up to 17pt, **3:1** for 18pt+ or any bold text.
  Check this against every theme's palette (`DiaryTheme.swift`) — six themes × two
  modes = 12 `textPrimary`-vs-`background` and `textSecondary`-vs-`background` pairs
  to check, not just the default. Pale/desaturated text-on-background combinations
  (an active concern in this app — several themes were deliberately tuned today for
  visible color saturation) are exactly the kind of pairing that can fail the ratio
  even when it "looks fine" to a sighted person with typical vision.
- **Don't rely on color alone.** The overdue-task badge and the due-date ring on
  `MiniMonthGrid` both currently communicate meaning via red color alone (`Color.red`)
  — check whether that's paired with a distinct shape/icon/text label too, or whether
  color is the *only* signal.
- **Prefer system-defined colors where practical** — they auto-adapt to Increase
  Contrast / Dark Mode. This app deliberately uses a custom theme system instead
  (`ThemeManager`/`DS`), which is a legitimate product decision, not a bug — but it
  does mean *this app*, not the system, is responsible for the contrast guarantee
  system colors would otherwise provide for free. Flag this as an explicit tradeoff
  the theme system took on, not something to "fix" by reverting to system colors.
- **VoiceOver**: every meaningful interactive element and every image that conveys
  information needs a label VoiceOver can speak. Audit for elements with no inherent
  label — icon-only buttons (SF Symbol buttons with no text, e.g. the corner
  Today/Archive icons in `RootView.swift`, the ellipsis/menu buttons, the calendar-
  jump/prev/next chevrons in `ExtendedPageView.swift`), and the `DiaryIllustrationView`
  decorative image (which should likely be explicitly marked as decorative/hidden from
  VoiceOver, not left to guess).

## 2. Mobility (pointer/keyboard, not touch — this is a Mac app)

Source: [Accessibility (HIG)](https://developer.apple.com/design/human-interface-guidelines/accessibility)

- **macOS control size**: default **28×28pt**, minimum **20×20pt**. Check small
  icon-only controls against this — several buttons in this app use quite small
  SF Symbol sizes (e.g. `.font(.system(size: 9))`/`size: 10` icons in task rows,
  `ExtendedPageView`'s prev/next/jump buttons) — the *tap target*, not just the glyph,
  needs to clear the minimum, which a small `Button` with no explicit `.frame()` or
  `.contentShape()` padding may not.
- **Padding between controls**: ~12pt around bezeled elements, ~24pt around
  non-bezeled elements is the HIG's own rule of thumb — worth spot-checking dense rows
  (task list action icons, the settings theme swatch grid).
- **Full Keyboard Access**: people can navigate a Mac app entirely by keyboard. Check
  whether every interactive element in this app (task checkboxes, theme swatches,
  the tear-off button, task row expand/collapse, the settings toggles) is actually
  reachable and operable via keyboard/Tab order, not just mouse/trackpad. This is a
  real risk area specifically because of `AppKitTaskTable` — a hand-rolled
  `NSTableView` wrapper bypasses SwiftUI's automatic focus/keyboard handling entirely,
  so its keyboard accessibility (if any) had to be built by hand, not inherited for
  free the way a plain SwiftUI `List` would get it.
- **Don't override system-defined keyboard shortcuts.** Check any custom keyboard
  handling (`NSEvent.addLocalMonitorForEvents` in `HibimekuriApp.swift`, if any
  shortcut-like key handling exists) doesn't clash with standard system shortcuts.

## 3. Cognitive

Source: [Accessibility (HIG)](https://developer.apple.com/design/human-interface-guidelines/accessibility)

- **Reduce Motion**: the app has several animated transitions (the compact↔extended
  `matchedGeometryEffect` morph, the illustration fade-in, the month-flip 3D rotation
  in `DayPageHeader`). None of these currently check
  `@Environment(\.accessibilityReduceMotion)`. Apple's guidance is explicit that apps
  should respond to this setting by reducing/removing non-essential motion — this is a
  concrete, checkable gap, not a stylistic nitpick, given how much of this app's recent
  work has specifically been about building smooth animated transitions.
- **Avoid time-boxed UI that auto-dismisses.** Scan for anything that disappears on a
  timer rather than an explicit user action (doesn't appear to apply here today, but
  worth confirming, not assuming).
- **Simple, consistent interactions** — this app already generally follows system
  conventions (standard buttons, standard text fields); no known violation, but the
  custom `AppKitTaskTable` drag-and-drop interaction is the one place worth a close
  look, since it's the one interaction in the app that isn't a standard SwiftUI
  control.

## 4. Hearing / Speech

Source: [Accessibility (HIG)](https://developer.apple.com/design/human-interface-guidelines/accessibility)

- No audio or video content exists in this app (it's a text/task diary), so captions/
  subtitles/audio-description guidance doesn't apply — don't flag it as a gap.
- Full Keyboard Access (covered under Mobility above) is the main relevant guidance
  here too, since it also serves people who prefer/need text- and keyboard-based
  interaction over gestures.

## 5. Testing method

Source: [Performing accessibility testing for your app](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app)

Apple's own recommended process, adapted to what's practical for an audit (vs. live
device testing with a screen reader on):

1. **List the app's main tasks** first (today's page: read the date/almanac, add/
   complete/reorder a task, write a note, switch days, tear off the page; archive:
   browse past entries, restore one; settings: change language/theme/mode/quote
   style/iCloud sync).
2. For each, check statically: is there a label a screen reader could speak, is there
   more than one sensory channel conveying the information, does it work without a
   mouse/trackpad.
3. **Use Accessibility Inspector** (ships with Xcode) if available in the environment,
   to check actual contrast ratios and the accessibility tree the app exposes — this
   catches things static code reading can miss (e.g. whether SwiftUI actually
   generated a sensible accessibility label from surrounding text, vs. requiring an
   explicit `.accessibilityLabel()`).
4. Where a live device/Inspector pass isn't possible in this environment, say so
   explicitly rather than presenting a static-code guess as if it were verified —
   this matches the standing project rule about verifying UI claims interactively,
   not just from reading code.

## 6. Inclusion (writing, imagery, assumptions)

Source: [Inclusion (HIG)](https://developer.apple.com/design/human-interface-guidelines/inclusion)

- **Language**: check UI copy (both Japanese and English strings, via `Localizer`)
  for gendered assumptions, unexplained jargon, or culture-specific idioms that
  wouldn't translate. This app already ships bilingual JA/EN copy by design, which is
  itself a strong inclusion signal — the check here is narrower: does either language's
  copy make assumptions (e.g. about family structure, ability, or background) the
  other doesn't need to.
- **No gendered imagery/avatars/characters exist in this app** (it's a personal diary/
  task tool, no user-representing avatars) — this section of the HIG is largely
  not applicable; don't manufacture findings here.
- **Color meaning across cultures**: the app's whole premise is a Japanese himekuri
  calendar with real cultural content (kanshi, rokuyō, kyūreki) — that's intentional
  cultural specificity, not something to genericize. The inclusion lens that *does*
  apply: is the almanac content presented respectfully and accurately (already a
  known, deliberate design goal per the app's own `SettingsView` disclaimer about the
  almanac being an approximation), not whether to remove it.

## 7. What NOT to flag

- iOS/iPadOS/watchOS/tvOS/visionOS-specific guidance (touch gesture alternatives,
  Assistive Access, Apple Watch control sizes, VoiceOver touch gestures) — this is a
  macOS-only app.
- Media accessibility (captions/subtitles/audio description) — no audio/video content
  exists in this app.
- Removing or genericizing the app's Japanese cultural content (himekuri format,
  almanac fields, idioms) in the name of "inclusion" — that content is the app's
  actual subject matter, not an inclusion gap.
- Speculative fixes with no plausible real user impact for an app this size — same
  standing rule as the Swift best-practices doc: audit against real, checkable
  criteria, don't manufacture busywork.
