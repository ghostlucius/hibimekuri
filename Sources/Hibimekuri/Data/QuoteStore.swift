import Foundation

@Observable
final class QuoteStore {
    private(set) var quotes: [Quote] = []

    init() {
        load()
    }

    private func load() {
        guard let url = AppResources.bundle.url(forResource: "quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Quote].self, from: data) else {
            quotes = []
            return
        }
        quotes = decoded
    }

    /// Deterministic quote for a given calendar day, stable across launches.
    func quote(for date: Date) -> Quote? {
        guard !quotes.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = Calendar.current.component(.year, from: date)
        let index = (dayOfYear + year) % quotes.count
        return quotes[index]
    }

    func quote(withId id: String) -> Quote? {
        quotes.first { $0.id == id }
    }
}
