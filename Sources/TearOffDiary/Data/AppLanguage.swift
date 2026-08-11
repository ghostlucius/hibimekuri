import SwiftUI

/// The colors in `DesignSystem.swift` resolve through `ThemeManager`, which
/// already tracks the effective light/dark scheme on its own (see its own
/// doc comment) — this only adds the explicit override macOS's own Settings
/// offers, stored separately from whatever the system is currently set to.
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

/// How long a deleted task stays recoverable in "Recently deleted" before
/// `TaskStore.purgeExpiredArchivedTasks()` removes it for good.
enum TaskRetention: Int, CaseIterable, Identifiable {
    case fifteenDays = 15
    case thirtyDays = 30
    case ninetyDays = 90

    var id: Int { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .fifteenDays: return Localizer.t("15日間", "15 days", language: language)
        case .thirtyDays: return Localizer.t("30日間", "30 days", language: language)
        case .ninetyDays: return Localizer.t("3ヶ月間", "3 months", language: language)
        }
    }
}
