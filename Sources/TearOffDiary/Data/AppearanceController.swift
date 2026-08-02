import AppKit

/// Drives the app's actual appearance directly through `NSApp.appearance`
/// rather than relying solely on SwiftUI's `.preferredColorScheme` — on
/// macOS that modifier didn't reliably revert once a previous session had
/// forced `.dark`, leaving the app stuck dark even after switching back to
/// "System" while the system itself was in Light mode. Setting
/// `NSApp.appearance = nil` is the actual, unambiguous "follow the system"
/// state at the AppKit layer.
enum AppearanceController {
    static func apply(_ appearance: AppAppearance) {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// Read directly from `UserDefaults` (not `@AppStorage`, which needs a
    /// View/App context) so this can run as early as
    /// `applicationDidFinishLaunching`, before any SwiftUI view exists.
    static func applyStoredPreference() {
        let raw = UserDefaults.standard.string(forKey: "appAppearance")
        apply(raw.flatMap(AppAppearance.init(rawValue:)) ?? .system)
    }
}
