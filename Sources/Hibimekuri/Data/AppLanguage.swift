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
    case italian
    case french
    case spanish

    /// Used until the user picks a language in Settings.
    static let fallback: AppLanguage = .english

    var id: String { rawValue }

    /// Always shown in the language's own name, so someone who landed in
    /// the wrong language can still find theirs.
    var displayName: String {
        switch self {
        case .japanese: "日本語"
        case .english: "English"
        case .italian: "Italiano"
        case .french: "Français"
        case .spanish: "Español"
        }
    }

    var locale: Locale {
        switch self {
        case .japanese: Locale(identifier: "ja_JP")
        case .english: Locale(identifier: "en_US")
        case .italian: Locale(identifier: "it_IT")
        case .french: Locale(identifier: "fr_FR")
        case .spanish: Locale(identifier: "es_ES")
        }
    }
}

/// Which source the daily quote card reads from. `.englishWord` is only
/// ever offered in English mode (see `SettingsView`'s DAILY QUOTE picker) —
/// it's an alternative for readers who'd rather not have Japanese content
/// at all. `.japaneseIdiom` and `.custom` are available in both languages.
enum QuoteStyle: String, CaseIterable, Identifiable {
    case japaneseIdiom
    case englishWord
    case custom

    var id: String { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .japaneseIdiom: return Localizer.t("日本語の引用", "Japanese idiom", language: language)
        case .englishWord: return Localizer.t("今日の単語", "Word of the day", language: language)
        case .custom: return Localizer.t("カスタム", "Custom", language: language)
        }
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
