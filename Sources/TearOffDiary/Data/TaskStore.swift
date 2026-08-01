import Foundation

@Observable
final class TaskStore {
    private(set) var tasks: [TaskItem] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("TearOffDiary", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("tasks.json")
        load()
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

    /// Reorder is scoped to the task's own group (active or done) — nudging
    /// never lets a task hop across that boundary.
    func moveUp(_ id: UUID) { nudge(id, by: -1) }
    func moveDown(_ id: UUID) { nudge(id, by: 1) }

    private func nudge(_ id: UUID, by delta: Int) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        var group = tasks.filter { $0.isDone == task.isDone }.sorted { $0.order < $1.order }
        guard let idx = group.firstIndex(where: { $0.id == id }) else { return }
        let target = idx + delta
        guard group.indices.contains(target) else { return }
        group.swapAt(idx, target)
        for (position, item) in group.enumerated() {
            if let ti = tasks.firstIndex(where: { $0.id == item.id }) {
                tasks[ti].order = position
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
