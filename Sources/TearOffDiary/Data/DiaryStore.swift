import Foundation
import AppKit

@MainActor
@Observable
final class DiaryStore {
    private(set) var entries: [DiaryEntry] = []
    private(set) var storageDirectory: URL
    private(set) var storageIssueMessage: String?

    private var fileURL: URL
    private var saveTask: Task<Void, Never>?
    private var saveSuspended = false
    private var isRelocating = false
    private var terminateObserver: NSObjectProtocol?

    init() {
        let dir = StorageLocation.activeDirectory
        storageDirectory = dir
        fileURL = dir.appendingPathComponent("entries.json")
        load()
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flushPendingSave()
            }
        }
    }

    /// Re-points the store after the iCloud setting changes without blindly
    /// overwriting whatever already exists at the destination. If both sides
    /// have data, merge by calendar day and back up both files first.
    ///
    /// The actual read/backup/write work happens off the main actor (see
    /// `Self.relocate`, `nonisolated`) — an iCloud path that hasn't finished
    /// downloading locally can stall a plain `Data(contentsOf:)` for
    /// seconds, and this store is `@MainActor`, so doing that work inline
    /// here would freeze Settings (and everything else) for as long as
    /// iCloud takes. `isRelocating` blocks re-entrancy while that's in
    /// flight, since a second relocation racing the first could each load
    /// a stale destination snapshot and clobber the other's write.
    func relocateStorage() {
        guard !isRelocating else { return }
        let newDir = StorageLocation.activeDirectory
        let newURL = newDir.appendingPathComponent("entries.json")
        guard newURL != fileURL else { return }

        let oldURL = fileURL
        saveTask?.cancel()
        let snapshot = entries
        isRelocating = true

        Task {
            defer { isRelocating = false }
            do {
                let merged = try await Self.relocate(current: snapshot, oldURL: oldURL, newURL: newURL)
                entries = merged
                fileURL = newURL
                storageDirectory = newDir
                storageIssueMessage = nil
                saveSuspended = false
                do {
                    try FileManager.default.removeItem(at: oldURL)
                } catch {
                    storageIssueMessage = Localizer.t(
                        "古い entries.json を削除できませんでした。データは新しい保存先にコピー済みです。",
                        "Couldn't remove the old entries.json. Your data was copied to the new storage location.",
                        language: currentLanguage
                    )
                }
            } catch {
                storageIssueMessage = JSONFilePersistence.message(for: error, fileName: "entries.json", language: currentLanguage)
                saveSuspended = true
            }
        }
    }

    private nonisolated static func relocate(current: [DiaryEntry], oldURL: URL, newURL: URL) async throws -> [DiaryEntry] {
        let destinationEntries = try JSONFilePersistence.loadArray([DiaryEntry].self, from: newURL)
        let preferDestination = (JSONFilePersistence.modificationDate(for: newURL) ?? .distantPast)
            > (JSONFilePersistence.modificationDate(for: oldURL) ?? .distantPast)
        let merged = mergedEntries(current: current, destination: destinationEntries, preferDestinationConflicts: preferDestination)

        _ = try JSONFilePersistence.backupExistingFile(at: oldURL, reason: "before-move")
        _ = try JSONFilePersistence.backupExistingFile(at: newURL, reason: "before-merge")
        try JSONFilePersistence.writeArraySynchronously(merged, to: newURL)
        return merged
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
        scheduleSave()
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
        scheduleSave()
    }

    private func load() {
        do {
            entries = try JSONFilePersistence.loadArray([DiaryEntry].self, from: fileURL)
            storageIssueMessage = nil
            saveSuspended = false
        } catch {
            do {
                _ = try JSONFilePersistence.backupExistingFile(at: fileURL, reason: "unreadable")
                try FileManager.default.removeItem(at: fileURL)
                entries = []
                storageIssueMessage = Localizer.t(
                    "entries.json を読み込めませんでした。元ファイルをバックアップし、新しい記録として開始しました。",
                    "Couldn't read entries.json. The original file was backed up and the app started a fresh entries file.",
                    language: currentLanguage
                )
                saveSuspended = false
            } catch {
                entries = []
                storageIssueMessage = JSONFilePersistence.message(for: error, fileName: "entries.json", language: currentLanguage)
                saveSuspended = true
            }
        }
    }

    private func scheduleSave() {
        guard !saveSuspended else { return }
        saveTask?.cancel()
        let snapshot = entries
        let targetURL = fileURL
        saveTask = Task { [weak self, snapshot, targetURL] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                try await JSONFilePersistence.writeArray(snapshot, to: targetURL)
                self?.storageIssueMessage = nil
            } catch is CancellationError {
                return
            } catch {
                self?.storageIssueMessage = JSONFilePersistence.message(for: error, fileName: "entries.json", language: self?.currentLanguage ?? .japanese)
            }
        }
    }

    func flushPendingSave() {
        guard !saveSuspended else { return }
        saveTask?.cancel()
        do {
            try JSONFilePersistence.writeArraySynchronously(entries, to: fileURL)
            storageIssueMessage = nil
        } catch {
            storageIssueMessage = JSONFilePersistence.message(for: error, fileName: "entries.json", language: currentLanguage)
        }
    }

    private var currentLanguage: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.japanese.rawValue
        return AppLanguage(rawValue: raw) ?? .japanese
    }

    private nonisolated static func mergedEntries(
        current: [DiaryEntry],
        destination: [DiaryEntry],
        preferDestinationConflicts: Bool
    ) -> [DiaryEntry] {
        // Not `uniqueKeysWithValues:` — that traps on a duplicate date,
        // and a runtime trap skips the do/catch entirely, crashing the app
        // on a malformed or externally-edited destination file instead of
        // surfacing `storageIssueMessage` like every other failure path
        // here. Keeping the first occurrence is an arbitrary but safe
        // tiebreak for data that should never have duplicates anyway.
        var byDate = Dictionary(destination.map { (DiaryEntry.startOfDay($0.date), $0) }, uniquingKeysWith: { first, _ in first })
        for entry in current {
            let key = DiaryEntry.startOfDay(entry.date)
            if let existing = byDate[key] {
                byDate[key] = preferDestinationConflicts ? existing : entry
            } else {
                byDate[key] = entry
            }
        }
        return byDate.values.sorted { $0.date < $1.date }
    }
}
