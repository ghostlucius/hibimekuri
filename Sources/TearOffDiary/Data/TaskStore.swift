import Foundation
import AppKit

@MainActor
@Observable
final class TaskStore {
    private(set) var tasks: [TaskItem] = []
    private(set) var storageDirectory: URL
    private(set) var storageIssueMessage: String?

    private var fileURL: URL
    private var dayChangeObserver: NSObjectProtocol?
    private var notificationAuthorizationObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var saveTask: Task<Void, Never>?
    private var saveSuspended = false

    init() {
        let dir = StorageLocation.activeDirectory
        storageDirectory = dir
        fileURL = dir.appendingPathComponent("tasks.json")
        load()
        purgeExpiredArchivedTasks()
        TaskNotificationScheduler.rescheduleAll(tasks)
        // A long-running session (app left open across midnight) should
        // still purge on schedule, not only at the next launch — mirrors
        // `AppIconManager`'s identical use of this notification for the
        // same "don't require a relaunch" reason.
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.purgeExpiredArchivedTasks()
            }
        }
        notificationAuthorizationObserver = NotificationCenter.default.addObserver(
            forName: .taskNotificationAuthorizationChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                TaskNotificationScheduler.rescheduleAll(self.tasks)
            }
        }
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flushPendingSave()
            }
        }
    }

    /// See `DiaryStore.relocateStorage()` — merge and back up rather than
    /// blindly overwriting whatever already exists at the destination.
    func relocateStorage() {
        let newDir = StorageLocation.activeDirectory
        let newURL = newDir.appendingPathComponent("tasks.json")
        guard newURL != fileURL else { return }

        let oldURL = fileURL
        saveTask?.cancel()

        do {
            let destinationTasks = try JSONFilePersistence.loadArray([TaskItem].self, from: newURL)
            let preferDestination = (JSONFilePersistence.modificationDate(for: newURL) ?? .distantPast)
                > (JSONFilePersistence.modificationDate(for: oldURL) ?? .distantPast)
            let merged = mergedTasks(current: tasks, destination: destinationTasks, preferDestinationConflicts: preferDestination)

            _ = try JSONFilePersistence.backupExistingFile(at: oldURL, reason: "before-move")
            _ = try JSONFilePersistence.backupExistingFile(at: newURL, reason: "before-merge")
            try JSONFilePersistence.writeArraySynchronously(merged, to: newURL)

            tasks = merged
            storageIssueMessage = nil
            saveSuspended = false
            TaskNotificationScheduler.rescheduleAll(tasks)
        } catch {
            storageIssueMessage = JSONFilePersistence.message(for: error, fileName: "tasks.json", language: currentLanguage)
            saveSuspended = true
            return
        }

        fileURL = newURL
        storageDirectory = newDir
        do {
            try FileManager.default.removeItem(at: oldURL)
        } catch {
            storageIssueMessage = Localizer.t(
                "古い tasks.json を削除できませんでした。データは新しい保存先にコピー済みです。",
                "Couldn't remove the old tasks.json. Your data was copied to the new storage location.",
                language: currentLanguage
            )
        }
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var task = TaskItem(title: trimmed)
        task.order = tasks.count
        tasks.append(task)
        scheduleSave()
    }

    func toggleDone(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isDone.toggle()
        tasks[idx].completedAt = tasks[idx].isDone ? Date() : nil
        scheduleSave()
        TaskNotificationScheduler.reschedule(for: tasks[idx])
    }

    /// Soft-delete: the task drops out of the normal active/done lists
    /// immediately (see each view's `visibleTasks`-style filter) but isn't
    /// actually erased until `purgeExpiredArchivedTasks()` removes it, past
    /// whatever retention `SettingsView`'s "Task retention" picker has set
    /// — see "Recently deleted" in Settings for the restore path.
    func delete(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].archivedAt = Date()
        scheduleSave()
        TaskNotificationScheduler.reschedule(for: tasks[idx])
    }

    func restore(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].archivedAt = nil
        scheduleSave()
        TaskNotificationScheduler.reschedule(for: tasks[idx])
    }

    /// Permanently removes any archived task older than the configured
    /// retention. Reads the setting directly from `UserDefaults` (like
    /// `AppearanceController.applyStoredPreference()` does) rather than
    /// needing a View/App context to read `@AppStorage`, since this also
    /// runs from `init()` and the day-change observer, neither of which
    /// has one.
    func purgeExpiredArchivedTasks() {
        let days = UserDefaults.standard.object(forKey: "taskRetentionDays") as? Int ?? TaskRetention.thirtyDays.rawValue
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        let before = tasks.count
        tasks.removeAll { task in
            guard let archivedAt = task.archivedAt else { return false }
            return archivedAt < cutoff
        }
        if tasks.count != before {
            scheduleSave()
            TaskNotificationScheduler.rescheduleAll(tasks)
        }
    }

    /// Replaces a task wholesale — used for edits (notes, defer date, …)
    /// that touch more than one field at once. `deferDate` doubles as this
    /// task's deadline (see `TaskItem`'s own doc comment), so every update
    /// re-syncs its reminder notification, not just the ones that meant to
    /// touch the date.
    func update(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        scheduleSave()
        TaskNotificationScheduler.reschedule(for: tasks[idx])
    }

    /// Commits a reorder from `AppKitTaskTable`'s real `NSTableView`-backed
    /// drag — `group` already reflects the final live-shifted order (the
    /// table's own `workingItems`, not a from/to offset pair), so this
    /// only ever reorders within that slice, never crossing the
    /// active/done boundary (each group gets its own table instance).
    func reorder(_ group: [TaskItem]) {
        for (position, item) in group.enumerated() {
            if let idx = tasks.firstIndex(where: { $0.id == item.id }) {
                tasks[idx].order = position
            }
        }
        scheduleSave()
    }

    func addChecklistItem(taskId: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].checklist.append(ChecklistItem(title: trimmed))
        scheduleSave()
    }

    func toggleChecklistItem(taskId: UUID, itemId: UUID) {
        guard let taskIdx = tasks.firstIndex(where: { $0.id == taskId }),
              let itemIdx = tasks[taskIdx].checklist.firstIndex(where: { $0.id == itemId }) else { return }
        tasks[taskIdx].checklist[itemIdx].isDone.toggle()
        scheduleSave()
    }

    func deleteChecklistItem(taskId: UUID, itemId: UUID) {
        guard let taskIdx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[taskIdx].checklist.removeAll { $0.id == itemId }
        scheduleSave()
    }

    private func load() {
        do {
            tasks = try JSONFilePersistence.loadArray([TaskItem].self, from: fileURL)
            storageIssueMessage = nil
            saveSuspended = false
        } catch {
            do {
                _ = try JSONFilePersistence.backupExistingFile(at: fileURL, reason: "unreadable")
                tasks = []
                storageIssueMessage = Localizer.t(
                    "tasks.json を読み込めませんでした。元ファイルをバックアップし、新しいタスクリストとして開始しました。",
                    "Couldn't read tasks.json. The original file was backed up and the app started a fresh task list.",
                    language: currentLanguage
                )
                saveSuspended = false
            } catch {
                tasks = []
                storageIssueMessage = JSONFilePersistence.message(for: error, fileName: "tasks.json", language: currentLanguage)
                saveSuspended = true
            }
        }
    }

    private func scheduleSave() {
        guard !saveSuspended else { return }
        saveTask?.cancel()
        let snapshot = tasks
        let targetURL = fileURL
        saveTask = Task { [weak self, snapshot, targetURL] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                try await JSONFilePersistence.writeArray(snapshot, to: targetURL)
                self?.storageIssueMessage = nil
            } catch is CancellationError {
                return
            } catch {
                self?.storageIssueMessage = JSONFilePersistence.message(for: error, fileName: "tasks.json", language: self?.currentLanguage ?? .japanese)
            }
        }
    }

    func flushPendingSave() {
        guard !saveSuspended else { return }
        saveTask?.cancel()
        do {
            try JSONFilePersistence.writeArraySynchronously(tasks, to: fileURL)
            storageIssueMessage = nil
        } catch {
            storageIssueMessage = JSONFilePersistence.message(for: error, fileName: "tasks.json", language: currentLanguage)
        }
    }

    private var currentLanguage: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.japanese.rawValue
        return AppLanguage(rawValue: raw) ?? .japanese
    }

    private func mergedTasks(
        current: [TaskItem],
        destination: [TaskItem],
        preferDestinationConflicts: Bool
    ) -> [TaskItem] {
        var byID = Dictionary(uniqueKeysWithValues: destination.map { ($0.id, $0) })
        for task in current {
            if let existing = byID[task.id] {
                byID[task.id] = preferDestinationConflicts ? existing : task
            } else {
                byID[task.id] = task
            }
        }
        return byID.values.sorted { $0.order < $1.order }
    }
}
