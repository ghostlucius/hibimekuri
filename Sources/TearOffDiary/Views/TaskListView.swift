import SwiftUI

/// A persistent task list, independent of any single diary day: items
/// carry forward until checked off instead of resetting, and each task
/// can expand into a Things-style checklist of sub-steps, a notes field,
/// and a "do later" defer date.
struct TaskListView: View {
    @Environment(TaskStore.self) private var store
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var newTaskText = ""
    @State private var expandedTaskIDs: Set<UUID> = []
    @State private var showDeferred = false
    @FocusState private var fieldFocused: Bool

    private var visibleTasks: [TaskItem] {
        store.tasks.filter { !isDeferred($0) }
    }

    private var activeTasks: [TaskItem] {
        visibleTasks.filter { !$0.isDone }.sorted { $0.order < $1.order }
    }

    private var doneTasks: [TaskItem] {
        visibleTasks.filter { $0.isDone }.sorted { $0.order < $1.order }
    }

    private var deferredTasks: [TaskItem] {
        store.tasks.filter { isDeferred($0) }.sorted { ($0.deferDate ?? .distantFuture) < ($1.deferDate ?? .distantFuture) }
    }

    private func isDeferred(_ task: TaskItem) -> Bool {
        guard !task.isDone, let deferDate = task.deferDate else { return false }
        return deferDate > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localizer.t("やること", "TO DO", language: language))
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            ForEach(activeTasks) { task in row(task) }
            ForEach(doneTasks) { task in row(task) }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField(Localizer.t("タスクを追加", "Add a task", language: language), text: $newTaskText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($fieldFocused)
                    .onSubmit(addTask)
            }
            .padding(.top, (activeTasks.isEmpty && doneTasks.isEmpty) ? 0 : 2)

            if !deferredTasks.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showDeferred.toggle() }
                } label: {
                    Text(Localizer.t("＋\(deferredTasks.count)件 予定あり", "+\(deferredTasks.count) scheduled", language: language))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                if showDeferred {
                    ForEach(deferredTasks) { task in row(task) }
                }
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        TaskRow(
            task: task,
            isExpanded: expandedTaskIDs.contains(task.id),
            onToggleExpand: { toggleExpand(task.id) }
        )
    }

    private func addTask() {
        store.add(title: newTaskText)
        newTaskText = ""
        fieldFocused = true
    }

    private func toggleExpand(_ id: UUID) {
        if expandedTaskIDs.contains(id) {
            expandedTaskIDs.remove(id)
        } else {
            expandedTaskIDs.insert(id)
        }
    }
}

/// Icon-only button with a real tap target — a bare SF Symbol on
/// `.buttonStyle(.plain)` is only hittable on its literal glyph pixels,
/// which made the row's move/delete/expand controls very easy to miss.
private struct IconButton: View {
    let systemName: String
    var size: CGFloat = 9
    var weight: Font.Weight = .semibold
    var color: Color = .secondary
    var rotation: Double = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(color)
                .rotationEffect(.degrees(rotation))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @Environment(TaskStore.self) private var store
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var newStepText = ""
    @State private var showDatePicker = false
    @State private var pendingDeferDate = Date()
    @FocusState private var stepFieldFocused: Bool

    private var notesBinding: Binding<String> {
        Binding(
            get: { task.notes },
            set: { newValue in
                var updated = task
                updated.notes = newValue
                store.update(updated)
            }
        )
    }

    /// Relative feedback for a defer date — "in N days" while still hidden,
    /// "Today" the day it reappears, "Overdue" (flagged red) if it arrived
    /// and is still sitting there undone. A date with no feedback at all
    /// isn't useful, which was the actual complaint.
    private var deferBadge: (text: String, isOverdue: Bool)? {
        guard !task.isDone, let deferDate = task.deferDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: deferDate)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        switch days {
        case ..<0:
            return (Localizer.t("期限切れ", "Overdue", language: language), true)
        case 0:
            return (Localizer.t("今日", "Today", language: language), false)
        case 1:
            return (Localizer.t("明日", "Tomorrow", language: language), false)
        default:
            return (Localizer.t("\(days)日後", "in \(days) days", language: language), false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                IconButton(systemName: task.isDone ? "checkmark.square.fill" : "square", size: 12, color: task.isDone ? .primary : .secondary) {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        store.toggleDone(task.id)
                    }
                }

                Text(task.title)
                    .font(.system(size: 12))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)

                if let badge = deferBadge {
                    Text(badge.text)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(badge.isOverdue ? Color.red : Color.secondary)
                }

                if !task.checklist.isEmpty {
                    Text(verbatim: "\(task.checklist.filter { $0.isDone }.count)/\(task.checklist.count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                IconButton(systemName: "chevron.up") { store.moveUp(task.id) }
                IconButton(systemName: "chevron.down") { store.moveDown(task.id) }
                IconButton(systemName: "xmark", size: 10, color: .secondary) { store.delete(task.id) }
                IconButton(systemName: "chevron.right", rotation: isExpanded ? 90 : 0, action: onToggleExpand)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    TextField(Localizer.t("メモ", "Notes", language: language), text: notesBinding, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    deferRow

                    ForEach(task.checklist) { item in
                        HStack(spacing: 4) {
                            IconButton(systemName: item.isDone ? "checkmark.square" : "square", size: 11, color: item.isDone ? .primary : .secondary) {
                                store.toggleChecklistItem(taskId: task.id, itemId: item.id)
                            }

                            Text(item.title)
                                .font(.system(size: 12))
                                .strikethrough(item.isDone)
                                .foregroundStyle(item.isDone ? .secondary : .primary)

                            Spacer()

                            IconButton(systemName: "xmark", size: 9) {
                                store.deleteChecklistItem(taskId: task.id, itemId: item.id)
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        TextField(Localizer.t("ステップを追加", "Add a step", language: language), text: $newStepText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .focused($stepFieldFocused)
                            .onSubmit {
                                store.addChecklistItem(taskId: task.id, title: newStepText)
                                newStepText = ""
                                stepFieldFocused = true
                            }
                    }
                }
                .padding(.leading, 22)
            }
        }
    }

    private var deferRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            if let deferDate = task.deferDate {
                Text(verbatim: "\(deferDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let badge = deferBadge {
                    Text(badge.text)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(badge.isOverdue ? Color.red : Color.secondary)
                }
                IconButton(systemName: "xmark", size: 9, action: clearDefer)
            } else if showDatePicker {
                DatePicker("", selection: $pendingDeferDate, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
                    .font(.system(size: 11))
                Button(Localizer.t("設定", "Set", language: language)) {
                    var updated = task
                    updated.deferDate = Calendar.current.startOfDay(for: pendingDeferDate)
                    store.update(updated)
                    showDatePicker = false
                }
                .font(.system(size: 11))
            } else {
                Button(Localizer.t("あとで…", "Do later…", language: language)) {
                    pendingDeferDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    showDatePicker = true
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func clearDefer() {
        var updated = task
        updated.deferDate = nil
        store.update(updated)
    }
}
