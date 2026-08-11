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
    func relocateStorage() {
        let newDir = StorageLocation.activeDirectory
        let newURL = newDir.appendingPathComponent("entries.json")
        guard newURL != fileURL else { return }

        let oldURL = fileURL
        saveTask?.cancel()

        do {
            let destinationEntries = try JSONFilePersistence.loadArray([DiaryEntry].self, from: newURL)
            let preferDestination = (JSONFilePersistence.modificationDate(for: newURL) ?? .distantPast)
                > (JSONFilePersistence.modificationDate(for: oldURL) ?? .distantPast)
            let merged = mergedEntries(current: entries, destination: destinationEntries, preferDestinationConflicts: preferDestination)

            _ = try JSONFilePersistence.backupExistingFile(at: oldURL, reason: "before-move")
            _ = try JSONFilePersistence.backupExistingFile(at: newURL, reason: "before-merge")
            try JSONFilePersistence.writeArraySynchronously(merged, to: newURL)

            entries = merged
            storageIssueMessage = nil
            saveSuspended = false
        } catch {
            storageIssueMessage = JSONFilePersistence.message(for: error, fileName: "entries.json", language: currentLanguage)
            saveSuspended = true
            return
        }

        fileURL = newURL
        storageDirectory = newDir
        do {
            try FileManager.default.removeItem(at: oldURL)
        } catch {
            storageIssueMessage = Localizer.t(
                "古い entries.json を削除できませんでした。データは新しい保存先にコピー済みです。",
                "Couldn't remove the old entries.json. Your data was copied to the new storage location.",
                language: currentLanguage
            )
        }
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

    private func mergedEntries(
        current: [DiaryEntry],
        destination: [DiaryEntry],
        preferDestinationConflicts: Bool
    ) -> [DiaryEntry] {
        var byDate = Dictionary(uniqueKeysWithValues: destination.map { (DiaryEntry.startOfDay($0.date), $0) })
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
