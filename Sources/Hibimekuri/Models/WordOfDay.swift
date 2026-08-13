import Foundation

struct WordOfDay: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let partOfSpeech: String
    let definition: String
    let example: String
}
