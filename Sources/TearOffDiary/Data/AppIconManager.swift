import SwiftUI
import AppKit

/// Swaps the running app's Dock icon between the Classic Light/Dark
/// variants (`AppIcon/generate_app_icon.swift` generates the .icns files,
/// `scripts/build_dmg.sh` copies them into Contents/Resources) to track
/// resolved appearance — the explicit Light/Dark choice, or the system's
/// own appearance when "System" is selected. Only affects the Dock tile of
/// the *running* app; the static Finder/bundle icon (before launch) stays
/// whichever one Info.plist's CFBundleIconFile points at, since a true
/// appearance-aware bundle icon needs Xcode's Icon Composer, unavailable
/// in this environment.
enum AppIconManager {
    static func apply(colorScheme: ColorScheme) {
        let name = colorScheme == .dark ? "AppIconDark" : "AppIcon"
        guard let path = Bundle.main.path(forResource: name, ofType: "icns"),
              let image = NSImage(contentsOfFile: path) else { return }
        NSApp.applicationIconImage = image
    }

    static func applyForCurrentSystemAppearance() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        apply(colorScheme: isDark ? .dark : .light)
    }
}
