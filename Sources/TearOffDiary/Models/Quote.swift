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
    let source: QuoteSource
    let attribution: String?
}
