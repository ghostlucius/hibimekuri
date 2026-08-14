import SwiftUI

/// Owns the active `DiaryTheme` (Classic/Matcha/Washi/Zen/Sakura) and
/// resolves it, together with the current light/dark scheme, into a
/// `ThemePalette` that `DS` reads from.
///
/// Deliberately does NOT track Light/Dark/System mode itself — that's
/// already handled by `AppAppearance` + `AppearanceController`, which sets
/// `NSApp.appearance` directly rather than relying on SwiftUI's
/// `.preferredColorScheme` (that modifier didn't reliably revert once a
/// previous session had forced `.dark` — see `AppearanceController`'s own
/// doc comment). Re-deriving mode here would risk quietly reintroducing
/// that exact bug. Instead, `systemColorScheme` is pushed in from
/// `RootView`'s existing `@Environment(\.colorScheme)` observer — the same
/// signal it already forwards to `AppIconManager` — so there's only ever
/// one source of truth for "what does light/dark currently resolve to".
///
/// `@Observable` (not `ObservableObject`/`@Published`) to match the rest of
/// the app's stores (`DiaryStore`, `TaskStore`, …).
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private static let storageKey = "diaryTheme"

    var theme: DiaryTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
        }
    }

    /// Pushed in from outside (see `RootView`) rather than self-detected —
    /// deliberately not another independent appearance-tracking mechanism.
    var systemColorScheme: ColorScheme = .light

    private init() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: Self.storageKey) ?? DiaryTheme.classic.rawValue
        // This neutral theme was originally called Sumi. Persist its new
        // Classic name so Sumi is available for a distinct future theme.
        if saved == "sumi" {
            self.theme = .classic
            defaults.set(DiaryTheme.classic.rawValue, forKey: Self.storageKey)
        } else {
            self.theme = DiaryTheme(rawValue: saved) ?? .classic
        }
    }

    var currentPalette: ThemePalette {
        systemColorScheme == .dark ? theme.definition.dark : theme.definition.light
    }

    /// Bundled SVG resource name (without extension) for the active
    /// theme/scheme, or nil if this theme has no illustration yet.
    var illustrationName: String? {
        systemColorScheme == .dark ? theme.definition.illustrationDark : theme.definition.illustrationLight
    }
}
