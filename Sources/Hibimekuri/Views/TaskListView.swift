import SwiftUI

/// A persistent task list, independent of any single diary day: items
/// carry forward until checked off instead of resetting, and each task
/// can expand into a notes field and a "do later" defer date.
struct TaskListView: View {
    var pageDate: Date? = nil

    @Environment(TaskStore.self) private var store
    @Environment(TaskInteractionController.self) private var interaction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var newTaskText = ""
    // Single-optional, not a Set — only one task is ever open at a time
    // (matching Things), so opening a different row naturally closes
    // whichever one was open, no extra bookkeeping needed for that case.
    @State private var showDeferred = false
    @FocusState private var fieldFocused: Bool

    private var expandedTaskID: UUID? { interaction.expandedTask(on: pageDate) }

    private var visibleTasks: [TaskItem] {
        store.tasks.filter { $0.archivedAt == nil && !isDeferred($0) }
    }

    private var activeTasks: [TaskItem] {
        visibleTasks.filter { !$0.isDone }.sorted { $0.order < $1.order }
    }

    private var doneTasks: [TaskItem] {
        visibleTasks.filter { $0.isDone }.sorted { $0.order < $1.order }
    }

    private var deferredTasks: [TaskItem] {
        store.tasks.filter { $0.archivedAt == nil && isDeferred($0) }.sorted { ($0.deferDate ?? .distantFuture) < ($1.deferDate ?? .distantFuture) }
    }

    private func isDeferred(_ task: TaskItem) -> Bool {
        guard !task.isDone, let deferDate = task.deferDate else { return false }
        return deferDate > Calendar.current.startOfDay(for: Date())
    }

    /// A rough, deliberately generous per-row height estimate so the
    /// wrapped `NSScrollView` can be given a sensible size within the
    /// page's own outer ScrollView, without depending on GeometryReader/
    /// PreferenceKey content measurement — that exact technique already
    /// failed silently once in this codebase (see requirements.md "round
    /// 3": the measured value stayed 0 for reasons never root-caused). If
    /// a task's editor runs long enough to exceed this, the
    /// table falls back to its own small internal scrollbar rather than
    /// clipping anything, which is a safe degradation, not a broken one.
    private func estimatedHeight(for group: [TaskItem], expanded: UUID?) -> CGFloat {
        let collapsedRowHeight: CGFloat = 28
        let expandedExtra: CGFloat = 170
        let hasExpanded = expanded.map { id in group.contains { $0.id == id } } ?? false
        return CGFloat(group.count) * collapsedRowHeight + (hasExpanded ? expandedExtra : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localizer.t("やること", "TO DO", language: language))
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            // Real NSTableView-backed drag-to-reorder (see
            // AppKitTaskTable.swift) — SwiftUI's own List and .draggable
            // were both tried and both hit real, confirmed platform limits
            // (accent-colored selection/insertion drawing with no
            // override; no way to declare .move over .copy), so this
            // wraps AppKit directly instead of working around either.
            // Active and done get their own table each, since reordering
            // must never cross that boundary.
            if !activeTasks.isEmpty {
                if expandedTaskID == nil {
                    AppKitTaskTable(items: activeTasks, taskStore: store, onReorder: { reordered in
                        store.reorder(reordered)
                    }) { task in row(task) }
                        .frame(height: estimatedHeight(for: activeTasks, expanded: nil))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(activeTasks) { task in row(task) }
                    }
                }
            }
            if !doneTasks.isEmpty {
                if expandedTaskID == nil {
                    AppKitTaskTable(items: doneTasks, taskStore: store, onReorder: { reordered in
                        store.reorder(reordered)
                    }) { task in row(task) }
                        .frame(height: estimatedHeight(for: doneTasks, expanded: nil))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(doneTasks) { task in row(task) }
                    }
                }
            }

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
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { showDeferred.toggle() }
                } label: {
                    Text(Localizer.t("＋\(deferredTasks.count)件 予定あり", "+\(deferredTasks.count) scheduled", language: language))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                if showDeferred {
                    // No reordering for deferred tasks (never had it, even
                    // before this rewrite), so plain rows are fine here.
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(deferredTasks) { task in row(task) }
                    }
                }
            }
        }
        // Things-style "click anywhere else closes/deselects it": this
        // fires on every mouse-down in the whole app (see
        // HibimekuriApp.swift), before whatever row was actually clicked
        // (if any) gets to reselect/reopen itself right after — so clicking
        // a different task cleanly switches to it, and clicking anything
        // that isn't a task row (the memo, the header, blank space) just
        // closes everything, matching how Things behaves.
        .onReceive(NotificationCenter.default.publisher(for: .taskInteractionReset)) { _ in
            interaction.close()
        }
        // This background is intentionally limited to the task section.
        // It receives clicks only in unused task-area space; controls and
        // editors above it keep their own interactions. That mirrors the
        // task-list-only dismissal boundary used by Things.
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { closeExpandedTask() }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        TaskRow(
            task: task,
            pageDate: pageDate,
            isExpanded: interaction.isExpanded(task.id, on: pageDate),
            isSelected: interaction.isSelected(task.id, on: pageDate),
            onOpen: {
                if interaction.isExpanded(task.id, on: pageDate) {
                    interaction.close()
                } else {
                    interaction.open(task.id, on: pageDate)
                }
            },
            onSelect: {
                // A click in the unused part of the open row is the
                // task-section's explicit dismissal affordance. Native
                // controls in the row (title, checkbox, delete) retain
                // their own handling and do not take this route.
                if interaction.isExpanded(task.id, on: pageDate) {
                    closeExpandedTask()
                } else {
                    interaction.select(task.id, on: pageDate)
                }
            }
        )
    }

    private func addTask() {
        store.add(title: newTaskText)
        newTaskText = ""
        fieldFocused = true
    }

    private func closeExpandedTask() {
        interaction.close()
    }
}

/// Icon-only button with a real tap target — a bare SF Symbol on
/// `.buttonStyle(.plain)` is only hittable on its literal glyph pixels,
/// which made the row's move/delete/expand controls very easy to miss.
private struct IconButton: View {
    let systemName: String
    let accessibilityLabel: String
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
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let pageDate: Date?
    let isExpanded: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onSelect: () -> Void

    @Environment(TaskStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var showDatePicker = false
    @State private var pendingDeferDate = Date()
    @FocusState private var titleFocused: Bool

    /// Focus Mode outlives this row: the page intentionally unmounts while
    /// its single editor is active. Resolve by id on every binding access so
    /// that editor keeps reading and writing the live task rather than the
    /// row's value snapshot.
    private var currentTask: TaskItem {
        store.tasks.first(where: { $0.id == task.id }) ?? task
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { currentTask.notes },
            set: { newValue in
                var updated = currentTask
                updated.notes = newValue
                store.update(updated)
            }
        )
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { task.title },
            set: { newValue in
                var updated = task
                updated.title = newValue
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
            HStack(spacing: 6) {
                IconButton(
                    systemName: task.isDone ? "checkmark.square.fill" : "square",
                    accessibilityLabel: task.isDone
                        ? Localizer.t("タスクを未完了にする", "Mark task incomplete", language: language)
                        : Localizer.t("タスクを完了", "Complete task", language: language),
                    size: 12,
                    color: task.isDone ? .primary : .secondary
                ) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) {
                        store.toggleDone(task.id)
                    }
                }

                titleView

                Spacer()

                if let badge = deferBadge {
                    Text(badge.text)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(badge.isOverdue ? Color.red : DS.textSecondary)
                }


                IconButton(
                    systemName: "xmark",
                    accessibilityLabel: Localizer.t("タスクを削除", "Delete task", language: language),
                    size: 10,
                    color: .secondary
                ) { store.delete(task.id) }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? DS.selection : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onOpen()
            }
            .onTapGesture(count: 1) {
                onSelect()
            }
            // Dragging is handled entirely by the enclosing
            // AppKitTaskTable's real NSTableView machinery now — no
            // .draggable/.dropDestination needed on the row content itself.

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    MarkdownNotesField(
                        text: notesBinding,
                        placeholder: Localizer.t("メモ", "Notes", language: language),
                        pageDate: pageDate
                    )

                    deferRow

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
                        .foregroundStyle(badge.isOverdue ? Color.red : DS.textSecondary)
                }
                IconButton(
                    systemName: "xmark",
                    accessibilityLabel: Localizer.t("日付を消去", "Clear date", language: language),
                    size: 9,
                    action: clearDefer
                )
            } else if showDatePicker {
                DatePicker("", selection: $pendingDeferDate, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
                    .font(.system(size: 11))
                    .accessibilityLabel(Localizer.t("締め切り日", "Due date", language: language))
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

    private var titleView: some View {
        Group {
            if task.isDone {
                Text(task.title)
                    .strikethrough(true)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(task.title)
                .accessibilityAction(named: Localizer.t("詳細を表示", "Show details", language: language)) {
                    onOpen()
                }
            } else if isExpanded {
                TextField("", text: titleBinding)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary)
                    .focused($titleFocused)
                    .accessibilityLabel(Localizer.t("タスク名", "Task title", language: language))
                    .onAppear {
                        DispatchQueue.main.async { titleFocused = true }
                    }
            } else {
                Text(task.title)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(task.title)
                .accessibilityAction(named: Localizer.t("詳細を表示", "Show details", language: language)) {
                    onOpen()
                }
            }
        }
        .font(.system(size: 12))
    }
}
