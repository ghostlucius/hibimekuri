import Foundation

/// Coordinates task-row selection across every retained day page. Tasks are
/// global, whereas `TodayView` keeps several pages alive in its pager; keeping
/// this state in one controller ensures a task note has one editor at a time.
@Observable
final class TaskInteractionController {
    private(set) var expandedTaskID: UUID?
    private(set) var expandedPageDate: Date?
    private(set) var selectedTaskID: UUID?
    private(set) var selectedPageDate: Date?

    func isExpanded(_ taskID: UUID, on pageDate: Date?) -> Bool {
        expandedTaskID == taskID && expandedPageDate == pageDate
    }

    func isSelected(_ taskID: UUID, on pageDate: Date?) -> Bool {
        selectedTaskID == taskID && selectedPageDate == pageDate
    }

    func open(_ taskID: UUID, on pageDate: Date?) {
        selectedTaskID = taskID
        selectedPageDate = pageDate
        expandedTaskID = taskID
        expandedPageDate = pageDate
    }

    func select(_ taskID: UUID, on pageDate: Date?) {
        selectedTaskID = taskID
        selectedPageDate = pageDate
        expandedTaskID = nil
        expandedPageDate = nil
    }

    func close() {
        selectedTaskID = nil
        selectedPageDate = nil
        expandedTaskID = nil
        expandedPageDate = nil
    }

    func hasExpandedTask(on pageDate: Date?) -> Bool {
        expandedTaskID != nil && expandedPageDate == pageDate
    }

    func expandedTask(on pageDate: Date?) -> UUID? {
        hasExpandedTask(on: pageDate) ? expandedTaskID : nil
    }
}
