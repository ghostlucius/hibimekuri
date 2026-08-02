import SwiftUI

/// The colors in `DesignSystem.swift` are all semantic (`.textBackgroundColor`,
/// `Color.primary`, …) so they already track the system appearance on their
/// own — this only adds the explicit override macOS's own Settings offers,
/// stored separately from whatever the system is currently set to.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .system: return Localizer.t("システム", "System", language: language)
        case .light: return Localizer.t("ライト", "Light", language: language)
        case .dark: return Localizer.t("ダーク", "Dark", language: language)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese
    case english

    var id: String { rawValue }

    var displayName: String {
        self == .japanese ? "日本語" : "English"
    }
}

/// Only meaningful in English mode: whether the daily quote card shows the
/// Japanese idiom (with its English meaning) or an English word of the day.
enum QuoteStyle: String, CaseIterable, Identifiable {
    case japaneseIdiom
    case englishWord

    var id: String { rawValue }

    var displayName: String {
        self == .japaneseIdiom ? "Japanese idiom" : "Word of the day"
    }
}
