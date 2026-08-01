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
        VStack(alignment: .leading, spacing: 8) {
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

private struct TaskRow: View {
    let task: TaskItem
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @Environment(TaskStore.self) private var store
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var isHovering = false
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

    private var isDeferred: Bool {
        guard !task.isDone, let deferDate = task.deferDate else { return false }
        return deferDate > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        store.toggleDone(task.id)
                    }
                } label: {
                    Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                        .foregroundStyle(task.isDone ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)

                Text(task.title)
                    .font(.system(size: 13))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)

                if isDeferred, let deferDate = task.deferDate {
                    Text(deferDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                if !task.checklist.isEmpty {
                    Text(verbatim: "\(task.checklist.filter { $0.isDone }.count)/\(task.checklist.count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if isHovering {
                    Button(action: { store.moveUp(task.id) }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    Button(action: { store.moveDown(task.id) }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    Button(action: { store.delete(task.id) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }
            .onHover { isHovering = $0 }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    TextField(Localizer.t("メモ", "Notes", language: language), text: notesBinding, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    deferRow

                    ForEach(task.checklist) { item in
                        HStack(spacing: 6) {
                            Button {
                                store.toggleChecklistItem(taskId: task.id, itemId: item.id)
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.square" : "square")
                                    .font(.system(size: 11))
                                    .foregroundStyle(item.isDone ? Color.primary : Color.secondary)
                            }
                            .buttonStyle(.plain)

                            Text(item.title)
                                .font(.system(size: 12))
                                .strikethrough(item.isDone)
                                .foregroundStyle(item.isDone ? .secondary : .primary)

                            Spacer()

                            Button(action: { store.deleteChecklistItem(taskId: task.id, itemId: item.id) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
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
                Text(Localizer.t("予定: \(deferDate.formatted(date: .abbreviated, time: .omitted))", "Scheduled: \(deferDate.formatted(date: .abbreviated, time: .omitted))", language: language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button(action: clearDefer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
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
        .buttonStyle(.plain)
    }

    private func clearDefer() {
        var updated = task
        updated.deferDate = nil
        store.update(updated)
    }
}
