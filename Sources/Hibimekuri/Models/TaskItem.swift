import Foundation

/// A persistent to-do, independent of any single diary day — it carries
/// forward until checked off, like Things' inbox items.
struct TaskItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?
    var notes: String = ""
    /// Manual sort position, scoped independently within the active and
    /// done groups (a task never needs a position relative to the other group).
    var order: Int = 0
    /// If set and in the future, the task is snoozed off the main list
    /// until this date, like Things' "when" scheduling. Also doubles as
    /// this task's deadline for the reminder notification (see
    /// `TaskStore`'s notification scheduling) — kept as one field rather
    /// than adding a second date, since the UI already treats it as a
    /// deadline via the Overdue/Today/in-N-days badge.
    var deferDate: Date?
    /// Soft-delete timestamp — a "deleted" task isn't actually erased
    /// until `TaskStore.purgeExpiredArchivedTasks()` removes it, past
    /// whatever retention window Settings has configured. Lets an
    /// accidental delete be undone instead of being an instant, permanent,
    /// unconfirmed data loss.
    var archivedAt: Date?
}
