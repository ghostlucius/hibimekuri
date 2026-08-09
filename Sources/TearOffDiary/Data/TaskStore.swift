import Foundation

@Observable
final class TaskStore {
    private(set) var tasks: [TaskItem] = []
    private(set) var storageDirectory: URL

    private var fileURL: URL

    init() {
        let dir = StorageLocation.activeDirectory
        storageDirectory = dir
        fileURL = dir.appendingPathComponent("tasks.json")
        load()
    }

    /// See `DiaryStore.relocateStorage()` — same move-not-copy behavior,
    /// kept in sync so entries and tasks always live in the same place.
    func relocateStorage() {
        let newDir = StorageLocation.activeDirectory
        let newURL = newDir.appendingPathComponent("tasks.json")
        guard newURL != fileURL else { return }
        let oldURL = fileURL
        fileURL = newURL
        storageDirectory = newDir
        save()
        try? FileManager.default.removeItem(at: oldURL)
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var task = TaskItem(title: trimmed)
        task.order = tasks.count
        tasks.append(task)
        save()
    }

    func toggleDone(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isDone.toggle()
        tasks[idx].completedAt = tasks[idx].isDone ? Date() : nil
        save()
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    /// Replaces a task wholesale — used for edits (notes, defer date, …)
    /// that touch more than one field at once.
    func update(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        save()
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
        save()
    }

    func addChecklistItem(taskId: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[idx].checklist.append(ChecklistItem(title: trimmed))
        save()
    }

    func toggleChecklistItem(taskId: UUID, itemId: UUID) {
        guard let taskIdx = tasks.firstIndex(where: { $0.id == taskId }),
              let itemIdx = tasks[taskIdx].checklist.firstIndex(where: { $0.id == itemId }) else { return }
        tasks[taskIdx].checklist[itemIdx].isDone.toggle()
        save()
    }

    func deleteChecklistItem(taskId: UUID, itemId: UUID) {
        guard let taskIdx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[taskIdx].checklist.removeAll { $0.id == itemId }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        tasks = (try? decoder.decode([TaskItem].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
