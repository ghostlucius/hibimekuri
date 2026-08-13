import Foundation

/// Holds whatever quote file the user has imported (see `SettingsView`'s
/// "Import Quotes…" control) — no bundled content of its own, unlike
/// `QuoteStore`/`WordStore`. The app never redistributes anyone's quotes;
/// it just reads whatever the user points it at, same as importing a photo
/// into any other app. See requirements.md, "Custom Quote", for why this
/// replaced an earlier bundled-anime-quotes idea (copyright/offline-first).
@MainActor
@Observable
final class CustomQuoteStore {
    private(set) var quotes: [CustomQuote] = []
    private(set) var storageIssueMessage: String?

    private var fileURL: URL
    private var isRelocating = false

    init() {
        let dir = StorageLocation.activeDirectory
        fileURL = dir.appendingPathComponent("customQuotes.json")
        load()
    }

    /// Deterministic quote for a given calendar day, stable across launches
    /// — same rotation scheme as `QuoteStore`/`WordStore`, so it works with
    /// however many quotes the user imported, not just exactly 365.
    func quote(for date: Date) -> CustomQuote? {
        guard !quotes.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = Calendar.current.component(.year, from: date)
        let index = (dayOfYear + year) % quotes.count
        return quotes[index]
    }

    /// Reads and validates the picked file off the main actor, then copies
    /// it into the app's own data directory (next to entries.json/
    /// tasks.json), replacing whatever was imported before — not read live
    /// from wherever the user originally put it.
    func importFile(from url: URL, language: AppLanguage) async {
        let targetURL = fileURL
        do {
            let entries = try await Self.readAndValidate(url: url)
            try await JSONFilePersistence.writeArray(entries, to: targetURL)
            quotes = Self.makeQuotes(from: entries)
            storageIssueMessage = nil
        } catch {
            storageIssueMessage = Self.message(for: error, language: language)
        }
    }

    private enum ImportError: Error {
        case empty
    }

    private nonisolated static func readAndValidate(url: URL) async throws -> [CustomQuoteEntry] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let entries = try decoder.decode([CustomQuoteEntry].self, from: data)
        guard !entries.isEmpty else { throw ImportError.empty }
        return entries
    }

    private nonisolated static func makeQuotes(from entries: [CustomQuoteEntry]) -> [CustomQuote] {
        entries.enumerated().map { CustomQuote(id: $0.offset, text: $0.element.text, attribution: $0.element.attribution) }
    }

    private nonisolated static func message(for error: Error, language: AppLanguage) -> String {
        if case ImportError.empty = error {
            return Localizer.t(
                "そのファイルには引用が含まれていません。",
                "That file doesn't contain any quotes.",
                language: language
            )
        }
        if error is DecodingError {
            return Localizer.t(
                "ファイルを読み込めませんでした。JSON形式を確認してください。",
                "Couldn't read that file — check it's valid JSON in the expected format.",
                language: language
            )
        }
        return JSONFilePersistence.message(for: error, fileName: "customQuotes.json", language: language)
    }

    private func load() {
        guard let entries = try? JSONFilePersistence.loadArray([CustomQuoteEntry].self, from: fileURL) else {
            quotes = []
            return
        }
        quotes = Self.makeQuotes(from: entries)
    }

    /// See `DiaryStore.relocateStorage()` for the fuller pattern this is a
    /// lighter version of — custom quotes are a single flat imported list
    /// with no per-entry identity to merge by (unlike diary entries keyed
    /// on date, or tasks keyed on id), so relocation just keeps whichever
    /// side was modified more recently instead of merging.
    ///
    /// Same off-main-actor rationale as `DiaryStore`/`TaskStore`: the actual
    /// read/backup/write happens in `Self.relocate`, `nonisolated`, so an
    /// iCloud path that hasn't finished downloading locally can't stall this
    /// `@MainActor` store (and freeze Settings) while it does. `isRelocating`
    /// blocks re-entrancy the same way.
    func relocateStorage() {
        guard !isRelocating else { return }
        let newDir = StorageLocation.activeDirectory
        let newURL = newDir.appendingPathComponent("customQuotes.json")
        guard newURL != fileURL else { return }

        let oldURL = fileURL
        let snapshot = quotes
        isRelocating = true

        Task {
            defer { isRelocating = false }
            let entries = await Self.relocate(current: snapshot, oldURL: oldURL, newURL: newURL)
            quotes = Self.makeQuotes(from: entries)
            fileURL = newURL
            try? FileManager.default.removeItem(at: oldURL)
        }
    }

    private nonisolated static func relocate(current: [CustomQuote], oldURL: URL, newURL: URL) async -> [CustomQuoteEntry] {
        let destExists = FileManager.default.fileExists(atPath: newURL.path)
        let preferDestination = destExists
            && (JSONFilePersistence.modificationDate(for: newURL) ?? .distantPast)
                > (JSONFilePersistence.modificationDate(for: oldURL) ?? .distantPast)

        _ = try? JSONFilePersistence.backupExistingFile(at: oldURL, reason: "before-move")
        _ = try? JSONFilePersistence.backupExistingFile(at: newURL, reason: "before-merge")

        if preferDestination, let entries = try? JSONFilePersistence.loadArray([CustomQuoteEntry].self, from: newURL) {
            return entries
        }
        let entries = current.map { CustomQuoteEntry(text: $0.text, attribution: $0.attribution) }
        if !entries.isEmpty {
            try? JSONFilePersistence.writeArraySynchronously(entries, to: newURL)
        }
        return entries
    }
}
