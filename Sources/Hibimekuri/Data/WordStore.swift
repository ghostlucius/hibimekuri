import Foundation

@Observable
final class WordStore {
    private(set) var words: [WordOfDay] = []

    init() {
        load()
    }

    private func load() {
        guard let url = AppResources.bundle.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([WordOfDay].self, from: data) else {
            words = []
            return
        }
        words = decoded
    }

    /// Deterministic word for a given calendar day, stable across launches
    /// — same rotation scheme as QuoteStore, so "today's" pick never changes.
    func word(for date: Date) -> WordOfDay? {
        guard !words.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = Calendar.current.component(.year, from: date)
        let index = (dayOfYear + year) % words.count
        return words[index]
    }
}
