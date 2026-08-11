import SwiftUI

/// All colors here read live from `ThemeManager.shared` — a plain global
/// singleton, not a SwiftUI `@Environment` value, so these work identically
/// whether called from a normal view body or from an isolated render tree
/// like `AppKitTaskTable`'s manual `ImageRenderer` drag-image snapshot
/// (which doesn't inherit the surrounding view's environment). Call sites
/// don't need to change when the active theme changes — as long as they're
/// evaluated from within a SwiftUI view's `body`, `@Observable`'s access
/// tracking picks up the read through this indirection just like a direct
/// property access, so the view still re-renders on theme changes.
enum DS {
    static let numeralFont = Font.system(size: 180, weight: .black, design: .default)
    static let smallCaption = Font.system(size: 11, weight: .medium, design: .default)

    private static var palette: ThemePalette { ThemeManager.shared.currentPalette }

    static var paper: Color { palette.background }
    static var text: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var hairline: Color { palette.border }
    // Task rows' own selection highlight — deliberately not using List's
    // native selection binding at all (see TaskListView.swift), since its
    // active-state color is raw NSTableView drawing that neither `.tint()`
    // nor `.listItemTint()` can override on macOS, always showing the
    // user's system accent color regardless. This is a plain background
    // color under our own control instead.
    static var selection: Color { palette.accent.opacity(0.12) }
}

/// Renders a short string as stacked single-character lines, mimicking
/// vertical Japanese calendar typography (e.g. 火/曜/日).
struct VerticalText: View {
    let text: String
    var font: Font = .system(size: 20, weight: .bold)

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(font)
            }
        }
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.hairline)
            .frame(height: 1)
    }
}
