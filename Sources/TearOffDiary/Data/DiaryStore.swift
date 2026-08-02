import Foundation

@Observable
final class DiaryStore {
    private(set) var entries: [DiaryEntry] = []
    private(set) var storageDirectory: URL

    private var fileURL: URL

    init() {
        let dir = StorageLocation.activeDirectory
        storageDirectory = dir
        fileURL = dir.appendingPathComponent("entries.json")
        load()
    }

    /// Re-points the store at wherever it should live after the iCloud
    /// setting changes, carrying the already-loaded data across (it's the
    /// freshest copy we have) and removing the stale file left behind at
    /// the old location rather than orphaning it.
    func relocateStorage() {
        let newDir = StorageLocation.activeDirectory
        let newURL = newDir.appendingPathComponent("entries.json")
        guard newURL != fileURL else { return }
        let oldURL = fileURL
        fileURL = newURL
        storageDirectory = newDir
        save()
        try? FileManager.default.removeItem(at: oldURL)
    }

    func entry(for date: Date) -> DiaryEntry? {
        let target = DiaryEntry.startOfDay(date)
        return entries.first { $0.date == target }
    }

    @discardableResult
    func ensureEntry(for date: Date, quoteStore: QuoteStore) -> DiaryEntry {
        let target = DiaryEntry.startOfDay(date)
        if let existing = entries.first(where: { $0.date == target }) {
            return existing
        }
        let quote = quoteStore.quote(for: target)
        let new = DiaryEntry(date: target, quoteId: quote?.id ?? "")
        entries.append(new)
        save()
        return new
    }

    /// The page that should currently be open and editable: the earliest
    /// incomplete entry (so a restored/un-torn page takes priority over the
    /// frontier), or the day after the latest completed entry if every
    /// entry so far has been torn off — which lets the user get ahead of
    /// the real calendar date by planning several days in one sitting.
    func currentDate() -> Date {
        if let earliestIncomplete = entries.filter({ !$0.isCompleted }).min(by: { $0.date < $1.date }) {
            return earliestIncomplete.date
        }
        if let latestCompleted = entries.filter({ $0.isCompleted }).max(by: { $0.date < $1.date }) {
            return Calendar.current.date(byAdding: .day, value: 1, to: latestCompleted.date) ?? DiaryEntry.startOfDay(Date())
        }
        return DiaryEntry.startOfDay(Date())
    }

    func upsert(_ entry: DiaryEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([DiaryEntry].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
