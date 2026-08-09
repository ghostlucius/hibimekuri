import SwiftUI

/// A persistent task list, independent of any single diary day: items
/// carry forward until checked off instead of resetting, and each task
/// can expand into a Things-style checklist of sub-steps, a notes field,
/// and a "do later" defer date.
struct TaskListView: View {
    @Environment(TaskStore.self) private var store
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var newTaskText = ""
    // Single-optional, not a Set — only one task is ever open at a time
    // (matching Things), so opening a different row naturally closes
    // whichever one was open, no extra bookkeeping needed for that case.
    @State private var expandedTaskID: UUID?
    @State private var selectedTaskID: UUID?
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

    /// A rough, deliberately generous per-row height estimate so the
    /// wrapped `NSScrollView` can be given a sensible size within the
    /// page's own outer ScrollView, without depending on GeometryReader/
    /// PreferenceKey content measurement — that exact technique already
    /// failed silently once in this codebase (see requirements.md "round
    /// 3": the measured value stayed 0 for reasons never root-caused). If
    /// a task's expanded checklist runs long enough to exceed this, the
    /// table falls back to its own small internal scrollbar rather than
    /// clipping anything, which is a safe degradation, not a broken one.
    private func estimatedHeight(for group: [TaskItem], expanded: UUID?) -> CGFloat {
        let collapsedRowHeight: CGFloat = 32
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
                AppKitTaskTable(items: activeTasks, taskStore: store, onReorder: { reordered in
                    store.reorder(reordered)
                }) { task in row(task) }
                    .frame(height: estimatedHeight(for: activeTasks, expanded: expandedTaskID))
            }
            if !doneTasks.isEmpty {
                AppKitTaskTable(items: doneTasks, taskStore: store, onReorder: { reordered in
                    store.reorder(reordered)
                }) { task in row(task) }
                    .frame(height: estimatedHeight(for: doneTasks, expanded: expandedTaskID))
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
                    withAnimation(.easeInOut(duration: 0.15)) { showDeferred.toggle() }
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
                    ForEach(deferredTasks) { task in row(task) }
                }
            }
        }
        // Things-style "click anywhere else closes/deselects it": this
        // fires on every mouse-down in the whole app (see
        // TearOffDiaryApp.swift), before whatever row was actually clicked
        // (if any) gets to reselect/reopen itself right after — so clicking
        // a different task cleanly switches to it, and clicking anything
        // that isn't a task row (the memo, the header, blank space) just
        // closes everything, matching how Things behaves.
        .onReceive(NotificationCenter.default.publisher(for: .taskInteractionReset)) { _ in
            selectedTaskID = nil
            expandedTaskID = nil
        }
    }

    private func row(_ task: TaskItem) -> some View {
        TaskRow(
            task: task,
            isExpanded: expandedTaskID == task.id,
            isSelected: selectedTaskID == task.id,
            onOpen: { expandedTaskID = task.id },
            onSelect: { selectedTaskID = task.id }
        )
    }

    private func addTask() {
        store.add(title: newTaskText)
        newTaskText = ""
        fieldFocused = true
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
    let isSelected: Bool
    let onOpen: () -> Void
    let onSelect: () -> Void

    @Environment(TaskStore.self) private var store
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var newStepText = ""
    @State private var showDatePicker = false
    @State private var pendingDeferDate = Date()
    @State private var isEditingTitle = false
    @FocusState private var stepFieldFocused: Bool
    @FocusState private var titleFocused: Bool

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
                IconButton(systemName: task.isDone ? "checkmark.square.fill" : "square", size: 12, color: task.isDone ? .primary : .secondary) {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        store.toggleDone(task.id)
                    }
                }

                titleView

                Spacer()

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

                IconButton(systemName: "xmark", size: 10, color: .secondary) { store.delete(task.id) }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? DS.selection : Color.clear)
            .contentShape(Rectangle())
            // Double-click always opens (never toggles closed) — closing
            // only happens by clicking elsewhere (see taskInteractionReset).
            .onTapGesture(count: 2) {
                onOpen()
                if !task.isDone {
                    isEditingTitle = true
                }
            }
            .onTapGesture(count: 1) {
                guard !isEditingTitle else { return }
                onSelect()
            }
            // Dragging is handled entirely by the enclosing
            // AppKitTaskTable's real NSTableView machinery now — no
            // .draggable/.dropDestination needed on the row content itself.

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    MarkdownNotesField(text: notesBinding, placeholder: Localizer.t("メモ", "Notes", language: language))

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

    /// Plain text until a double-click on the row starts a rename — a
    /// single click now only selects (see `body`), so the title can't stay
    /// an always-live `TextField` the way it used to. Done tasks stay a
    /// plain strikethrough Text always: renaming something already
    /// finished isn't wired up, and `.strikethrough` doesn't render on a
    /// `TextField` anyway.
    private var titleView: some View {
        Group {
            if task.isDone {
                Text(task.title)
                    .strikethrough(true)
                    .foregroundStyle(.secondary)
            } else if isEditingTitle {
                TextField("", text: titleBinding)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary)
                    .focused($titleFocused)
                    // Deferred to the next run-loop turn, not set
                    // synchronously — double-click fires onOpen() (which
                    // expands the whole notes/checklist section below, a
                    // real layout change) in the very same handler that
                    // starts this rename, and requesting focus in the same
                    // transaction as that layout change is a known SwiftUI/
                    // macOS race: the focus request can silently get
                    // dropped while the view hierarchy is mid-rebuild.
                    // Confirmed via real click/drag testing — this isn't
                    // theoretical, it reliably left the field looking
                    // editable but not actually focused.
                    .onChange(of: isEditingTitle, initial: true) { _, editing in
                        if editing {
                            DispatchQueue.main.async { titleFocused = true }
                        } else {
                            titleFocused = false
                        }
                    }
                    .onChange(of: titleFocused) { _, focused in
                        if !focused { isEditingTitle = false }
                    }
            } else {
                Text(task.title)
                    .foregroundStyle(.primary)
            }
        }
        .font(.system(size: 12))
        // If the row gets closed from outside (clicking elsewhere resets
        // the parent's expandedTaskID — see taskInteractionReset), local
        // rename state has to follow it explicitly: isEditingTitle is this
        // view's own @State, untouched by that reset, so without this the
        // title could stay silently "in edit mode" (an unfocused TextField
        // masquerading as plain text) indefinitely — which is exactly what
        // made a later click land on stale text-cursor positioning instead
        // of the row's own tap gesture.
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                isEditingTitle = false
            }
        }
    }
}
