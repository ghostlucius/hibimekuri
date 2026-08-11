# Apple Swift/SwiftUI Best Practices — Reference for Code Review

This document exists for one purpose: to give a code-reviewing agent (or a human) a
concrete, checkable standard to hold `TearOffDiary` against. Every section below is
either sourced directly from Apple's own developer documentation (linked), or marked
as general Swift-community style guidance where it isn't.

Project context this checklist should be applied against: a **macOS-only SwiftUI app**
(`Package.swift` declares `platforms: [.macOS(.v14)]`), built via plain SwiftPM
(`swift build`), not an Xcode project. There is real AppKit interop (`AppKitTaskTable`,
`AppDelegate`), a handful of `GeometryReader` usages, and an `@Observable`-based data
layer (`DiaryStore`, `TaskStore`, `ThemeManager`, ...). Keep recommendations scoped to
what actually applies here — don't invent iOS-only or Xcode-project-only advice for a
target that doesn't have it.

## 1. Ship a universal binary (Apple Silicon + Intel)

Source: [Building a universal macOS binary](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)

- A macOS binary that ships to people outside this machine should contain **both**
  `arm64` and `x86_64` slices unless there's a deliberate reason to drop Intel support.
  A single-architecture Intel Mac cannot run an arm64-only binary at all (there's no
  translation in that direction — Rosetta only goes arm64-host running x86_64 code).
- Check any built binary with `lipo -archs path/to/Binary`. It should print
  `x86_64 arm64`, not just one.
- To build both slices with a plain `swift build` (no Xcode project), build each
  architecture separately and merge with `lipo -create`, e.g.:
  ```bash
  swift build -c release --arch arm64
  swift build -c release --arch x86_64
  lipo -create -output TearOffDiary \
    .build/arm64-apple-macosx/release/TearOffDiary \
    .build/x86_64-apple-macosx/release/TearOffDiary
  ```
- **Verified finding for this project (2026-08-11):** `dist/TearOffDiary.app`'s binary
  is `arm64` only. On an Intel Mac this app does not launch at all. If any recipient of
  this build might be on an Intel Mac, `scripts/build_dmg.sh` needs the lipo step above.
- Wrap genuinely architecture-specific code (rare in a SwiftUI CRUD app like this one)
  in `#if arch(arm64)` / `#elseif arch(x86_64)`, not runtime checks.

## 2. SwiftUI performance

Source: [Understanding and improving SwiftUI performance](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)

- **Keep `body` cheap.** Don't do expensive computation, formatting, or filtering
  inline in a view's `body` — precompute it in the model/store, or cache it. SwiftUI
  recomputes `body` frequently; anything slow there is slow on every redraw.
- **Move business logic out of views and into model types.** Views get recreated and
  their `body` recalculated often — they're not the place for anything beyond
  assembling already-prepared data into a layout.
- **`GeometryReader` and `ScrollViewReader` recalculate on every parent layout
  change**, not just the changes you care about. Apple's own example of a bad pattern
  is a `GeometryReader` recalculating scroll geometry on updates that don't actually
  change scroll position. If a `GeometryReader`-driven view is doing more work than it
  needs to, narrow what triggers it, or move state that doesn't affect layout into a
  sibling view instead of inside the `GeometryReader`'s subtree.
  - **This project already hit two real bugs from `GeometryReader` misuse this
    session**: it silently doesn't animate `.opacity()` on children when combined with
    an `Image(nsImage:)` (worked around with a scrim overlay placed *outside* the
    reader — see `DiaryIllustrationView.swift`), and `.aspectRatio(.fill)` doesn't
    reliably size against a flexible parent without measuring an explicit target frame
    through one. Treat every `GeometryReader` in this codebase as a spot worth a second
    look, not just new ones.
- **Avoid storing closures in views** when avoidable. A closure captured in a view
  (especially one that captures `self` or view properties) forces SwiftUI to
  recalculate it whenever any captured state changes. For a closure passed to a view's
  initializer that just builds a child view, call it once in the initializer and store
  the *result*, not the closure itself.
- **Prefer `@Observable` over the old `ObservableObject` protocol** for new model
  types — `@Observable` only triggers a view update when a property the view's `body`
  actually *read* changes, not any observable property on the object. This project
  already follows this correctly (`DiaryStore`, `TaskStore`, `ThemeManager`, etc. are
  all `@Observable`) — flag any new `ObservableObject`/`@Published` usage as a
  regression back to the old, coarser-grained pattern.
- Use Instruments' SwiftUI template (Update Groups, Long View Body Updates lanes) to
  actually measure before assuming something is slow — orange = body update over
  500µs, red = over 1000µs.

## 3. App / UI responsiveness

Sources: [Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness), [Understanding user interface responsiveness](https://developer.apple.com/documentation/xcode/understanding-user-interface-responsiveness)

- **Rough budgets to know, not to over-engineer around**: a discrete interaction (a
  click, a keypress) starts reading as a "hang" past ~100ms of main-thread work; a
  continuous interaction (drag, scroll) needs each frame ready within one display
  refresh interval (~8–17ms) or it "hitches" (stutters).
- **Only UI work belongs on the main thread.** File I/O, JSON encode/decode, anything
  that isn't touching the view hierarchy, should not block the main thread —
  including *asynchronously* dispatching it there (e.g. `Task { @MainActor in ... }`
  for something that doesn't need to be on the main actor is still occupying it when it
  finally runs).
- **Swift concurrency `Task {}` inherits the actor of its enclosing context.** A
  `Task { doWork() }` called from inside a `@MainActor`-isolated SwiftUI view's `body`
  or an action closure still runs `doWork()` on the main actor unless `doWork()` is
  itself a `nonisolated async` function. If the work is synchronous and shouldn't block
  the main thread, use `Task.detached { ... }` explicitly, not a plain `Task {}` — a
  plain `Task {}` around synchronous work is a common mistake that looks like it fixes
  a hang but just delays it.
  - **Check this project's stores for exactly this pattern** — `DiaryStore`/`TaskStore`
    read/write JSON to disk synchronously; confirm those calls aren't happening
    directly on the main actor in a way that could hang the UI on a slow disk (e.g.
    iCloud Drive), or if they are, that the files are small enough it doesn't matter in
    practice (verify, don't assume).
- Prefer GCD/Swift concurrency's managed thread pools over hand-rolled `Thread`/spin
  locks — the system already tunes pool size to the device, custom thread pools don't.

## 4. Build efficiency (compile-time coding habits)

Source: [Improving build efficiency with good coding practices](https://developer.apple.com/documentation/xcode/improving-build-efficiency-with-good-coding-practices)

- **Give the compiler explicit types where inference would otherwise have to evaluate
  a nontrivial expression** (e.g. a `reduce`, a multi-step chain). Explicit typing on
  a stored property whose initializer isn't a simple literal both speeds up
  compilation and gives better error messages. Simple literals (`let x = "hi"`,
  `let y = 5`) should stay inferred — don't add redundant type annotations everywhere,
  only where the initializer expression is genuinely complex.
- **Avoid `AnyObject`/`Any`-typed delegate or callback properties.** They force the
  compiler to search the whole project for a matching method at every call site.
  Prefer an explicit protocol. (Less relevant here — this project doesn't really use
  the delegate pattern outside of the necessary `NSWindowDelegate`/`NSApplicationDelegate`
  conformances, which are unavoidable AppKit APIs, not something to "fix.")
- **Keep single-expression closures readable and simple.** An extremely dense one-line
  ternary/ternary-chain closure (Apple's own example: a triple-nested ternary inside a
  `reduce`) can make the type checker time out entirely, not just run slowly. If a
  closure needs more than one real branch of logic, write it as an `if`/`guard` block
  across multiple lines, not a compressed one-liner.
- This project builds via SwiftPM directly, not an Xcode project — module-map/bridging-
  header advice from Apple's docs (Objective-C ⇄ Swift symbol exposure) doesn't apply
  since there's no Objective-C in this codebase. Skip that advice; it's not actionable
  here.

## 5. General Swift style (community convention, not an Apple doc)

The following is standard, widely-taught Swift style — useful as a baseline, but treat
it as lower priority than sections 1–4 above, which are Apple's own stated guidance.

- Let type inference work for simple literals; add explicit types only per §4 above.
- Prefer `if let` / `guard let` over force-unwrapping (`!`). A force-unwrap should be
  reserved for a case that's a genuine programmer error to violate (e.g. an invariant
  already checked earlier in the same function), never for "this is probably fine."
- Prefer `struct` for models without identity or shared mutable state; reach for
  `class` (or here, `@Observable class`) only when reference semantics are actually
  needed — which is correct and expected for this project's stores.
- Keep closures concise (`{ $0 * $0 }` over a fully-spelled-out
  `{ (x: Int) -> Int in return x * x }`) — but see §4's caution about not going so far
  it hurts compile time or readability.
- Favor protocols + protocol extensions for shared default behavior over base-class
  inheritance, where reuse is actually needed.
- Naming: `camelCase` for values/functions, `PascalCase` for types/protocols, boolean
  properties prefixed `is`/`has`/`can`. This codebase already follows this
  consistently — flag any drift, don't rewrite what already conforms.

## 6. What NOT to flag

To keep review noise low, do **not** raise:
- Missing iOS-specific guidance (`UIKit`, `UIApplication`, size classes, etc.) — this
  target is macOS-only by design (see project context above).
- Missing Xcode-project-only build settings (Explicit Modules, bridging headers,
  Architectures build setting) — this project builds via `Package.swift` + `swift
  build`/`swift run`, there is no `.xcodeproj`.
- Rewriting working `@Observable` stores to something else, or renaming
  already-consistent identifiers, "for style" with no functional benefit.
- Pure micro-optimizations with no measured or plausible real-world impact for an app
  this size (a personal diary/task app, not a game or data-processing tool) — Apple's
  own performance doc (§3 above) explicitly frames this as "measure, then fix the
  biggest thing," not "optimize everything speculatively."
