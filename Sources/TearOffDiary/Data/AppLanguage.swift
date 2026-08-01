import Foundation

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
