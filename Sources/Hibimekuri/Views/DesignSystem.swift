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
    static var numeralFont: Font { displayFont(size: 180, weight: .black) }
    static var smallCaption: Font { displayFont(size: 11, weight: .medium) }

    private static var palette: ThemePalette { ThemeManager.shared.currentPalette }

    static var paper: Color { palette.background }
    static var text: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var hairline: Color { palette.border }

    /// Typography remains consistent across themes. Sumi changes the paper
    /// and ink colors only, preserving the app's established type system.
    static func displayFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Task selection follows the active theme. Classic is intentionally
    /// monochrome, so it uses a neutral wash rather than an unrelated color.
    static var selection: Color {
        switch ThemeManager.shared.theme {
        case .classic:
            return palette.textPrimary.opacity(0.10)
        case .sumi, .matcha, .washi, .zen, .sakura:
            return palette.accent.opacity(0.12)
        }
    }
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
