import SwiftUI

// MARK: - Hex color helper

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s.removeAll { $0 == "#" }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Theme enum

enum DiaryTheme: String, CaseIterable, Identifiable {
    case classic, matcha, washi, sumi, zen, sakura
    var id: String { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .classic: return Localizer.t("クラシック", "Classic", language: language)
        case .matcha: return Localizer.t("抹茶", "Matcha", language: language)
        case .washi: return Localizer.t("和紙", "Washi", language: language)
        case .sumi: return Localizer.t("墨", "Sumi", language: language)
        case .zen: return Localizer.t("禅", "Zen", language: language)
        case .sakura: return Localizer.t("桜", "Sakura", language: language)
        }
    }
}

// MARK: - Palette

struct ThemePalette {
    let background: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let accentStrong: Color
    let border: Color
}

struct ThemeDefinition {
    let light: ThemePalette
    let dark: ThemePalette
    /// Bundled resource name (without extension), or nil if this theme has
    /// no illustration yet — see `DiaryIllustrationView`.
    let illustrationLight: String?
    let illustrationDark: String?
}

// MARK: - Catalog

extension DiaryTheme {
    var definition: ThemeDefinition {
        switch self {
        case .classic:
            return ThemeDefinition(
                light: ThemePalette(
                    background: Color(hex: "FAFAF8"),
                    textPrimary: Color(hex: "2B2B28"),
                    textSecondary: Color(hex: "6B6A64"),
                    accent: Color(hex: "8B3A2F"),
                    accentStrong: Color(hex: "6E2C23"),
                    border: Color(hex: "D8D6D0")
                ),
                dark: ThemePalette(
                    background: Color(hex: "1C1C1A"),
                    textPrimary: Color(hex: "EDECE8"),
                    textSecondary: Color(hex: "A6A5A0"),
                    accent: Color(hex: "C1584A"),
                    accentStrong: Color(hex: "8B3A2F"),
                    border: Color(hex: "3A3A37")
                ),
                illustrationLight: "fuji-pagoda-classic-light",
                illustrationDark: "fuji-pagoda-classic-dark"
            )

        case .matcha:
            return ThemeDefinition(
                light: ThemePalette(
                    background: Color(hex: "F3F1E4"),
                    textPrimary: Color(hex: "33402C"),
                    textSecondary: Color(hex: "5C7350"),
                    accent: Color(hex: "7C9B6C"),
                    accentStrong: Color(hex: "2F4A2E"),
                    border: Color(hex: "A9BC94")
                ),
                dark: ThemePalette(
                    background: Color(hex: "10190F"),
                    textPrimary: Color(hex: "A8C79A"),
                    textSecondary: Color(hex: "7FA06B"),
                    accent: Color(hex: "A8C79A"),
                    accentStrong: Color(hex: "6B8F5A"),
                    border: Color(hex: "2C3D26")
                ),
                illustrationLight: "fuji-pagoda-matcha-light",
                illustrationDark: "fuji-pagoda-matcha-dark"
            )

        case .washi:
            return ThemeDefinition(
                light: ThemePalette(
                    background: Color(hex: "F2E9D8"),
                    textPrimary: Color(hex: "2E2418"),
                    textSecondary: Color(hex: "6B5A3E"),
                    accent: Color(hex: "A6813C"),
                    accentStrong: Color(hex: "7A5A26"),
                    border: Color(hex: "DDD0B0")
                ),
                dark: ThemePalette(
                    background: Color(hex: "1A140D"),
                    // A visibly warm gold, not a desaturated near-white —
                    // Matcha's pale-but-clearly-green dark text is the
                    // precedent; the earlier EDE1C8 read as plain white.
                    textPrimary: Color(hex: "E6C979"),
                    textSecondary: Color(hex: "B8A67E"),
                    accent: Color(hex: "C9A24E"),
                    accentStrong: Color(hex: "E0BC6C"),
                    border: Color(hex: "352A1A")
                ),
                illustrationLight: "fuji-pagoda-washi-light",
                illustrationDark: "fuji-pagoda-washi-dark"
            )

        case .sumi:
            // Pushed to the true black/white extremes — Sumi is "ink," so
            // it should read starker than Classic's soft warm neutral, not
            // sit a few shades away from it. Confirmed via testing that
            // the earlier, closer values made a theme switch to Sumi look
            // like nothing had changed except the illustration.
            return ThemeDefinition(
                light: ThemePalette(
                    background: Color(hex: "FCFCFB"),
                    textPrimary: Color(hex: "090909"),
                    textSecondary: Color(hex: "5C5C58"),
                    accent: Color(hex: "3A3A38"),
                    accentStrong: Color(hex: "090909"),
                    border: Color(hex: "D6D2C8")
                ),
                dark: ThemePalette(
                    background: Color(hex: "000000"),
                    textPrimary: Color(hex: "FAFAF8"),
                    textSecondary: Color(hex: "9C9C96"),
                    accent: Color(hex: "E8E6E0"),
                    accentStrong: Color(hex: "FFFFFF"),
                    border: Color(hex: "2A2A27")
                ),
                illustrationLight: "fuji-pagoda-sumi-light",
                illustrationDark: "fuji-pagoda-sumi-dark"
            )

        case .zen:
            // A distinctly cooler, greener gray than Classic's warm
            // neutral or Sumi's stark black/white — same reasoning as
            // Sumi above, pushed in the opposite (soft, muted) direction
            // instead of toward the extremes.
            return ThemeDefinition(
                light: ThemePalette(
                    background: Color(hex: "E5E8E3"),
                    textPrimary: Color(hex: "2A2F29"),
                    textSecondary: Color(hex: "5B6058"),
                    accent: Color(hex: "6E7A6A"),
                    accentStrong: Color(hex: "424940"),
                    border: Color(hex: "C7CCC3")
                ),
                dark: ThemePalette(
                    background: Color(hex: "121613"),
                    textPrimary: Color(hex: "DCE2D8"),
                    textSecondary: Color(hex: "8F9A8B"),
                    accent: Color(hex: "7C8A76"),
                    accentStrong: Color(hex: "A9B7A3"),
                    border: Color(hex: "283028")
                ),
                illustrationLight: "fuji-pagoda-zen-light",
                illustrationDark: "fuji-pagoda-zen-dark"
            )

        case .sakura:
            return ThemeDefinition(
                light: ThemePalette(
                    background: Color(hex: "FBF2EF"),
                    textPrimary: Color(hex: "2B2422"),
                    textSecondary: Color(hex: "70514D"),
                    accent: Color(hex: "D98CA0"),
                    accentStrong: Color(hex: "B85C77"),
                    border: Color(hex: "F0D9D4")
                ),
                dark: ThemePalette(
                    background: Color(hex: "1C1417"),
                    // A visibly warm rose, not a desaturated near-white —
                    // same reasoning as Washi's dark text above.
                    textPrimary: Color(hex: "E8B4C6"),
                    textSecondary: Color(hex: "C4A19D"),
                    accent: Color(hex: "C97E96"),
                    accentStrong: Color(hex: "E3A8BE"),
                    border: Color(hex: "3A2530")
                ),
                illustrationLight: "fuji-pagoda-sakura-light",
                illustrationDark: "fuji-pagoda-sakura-dark"
            )
        }
    }
}
