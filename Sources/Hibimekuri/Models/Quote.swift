import Foundation

enum QuoteSource: String, Codable {
    case proverb
    case yojijukugo
    case literature

    var label: String {
        switch self {
        case .proverb: "Proverb"
        case .yojijukugo: "Idiom"
        case .literature: "Literature"
        }
    }
}

struct Quote: Codable, Identifiable, Hashable {
    let id: String
    let japanese: String
    let english: String
    let italian: String?
    let french: String?
    let spanish: String?
    let source: QuoteSource
    let attribution: String?

    /// The meaning shown under the Japanese original; `nil` in Japanese
    /// mode. Falls back to English for a quote with no translation.
    func meaning(in language: AppLanguage) -> String? {
        switch language {
        case .japanese: nil
        case .english: english
        case .italian: italian ?? english
        case .french: french ?? english
        case .spanish: spanish ?? english
        }
    }
}
