import Foundation

struct ChecklistItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
}

/// A persistent to-do, independent of any single diary day — it carries
/// forward until checked off, like Things' inbox items. Can optionally
/// hold a checklist of sub-steps.
struct TaskItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?
    var checklist: [ChecklistItem] = []
    var notes: String = ""
    /// Manual sort position, scoped independently within the active and
    /// done groups (a task never needs a position relative to the other group).
    var order: Int = 0
    /// If set and in the future, the task is snoozed off the main list
    /// until this date, like Things' "when" scheduling.
    var deferDate: Date?
}
