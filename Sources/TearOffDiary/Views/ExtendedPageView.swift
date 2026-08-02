import SwiftUI

/// The wide-window layout — a real redesigned two-pane view, not the
/// compact page centered on more background (that was tried first and
/// rejected). Left pane: header, numeral, almanac column, compact mini
/// calendars. Right pane: tasks, note, idiom, tear-off button, with more
/// room to breathe than the compact page's single column.
///
/// Styled with the app's existing default look (black/white, same as the
/// compact page) — there's no actual theme system to pick "Matcha" from
/// yet, so this shouldn't invent a one-off green theme nobody can select
/// (tried once, reverted per the user 2026-08-02). The dot-grid drag handle
/// and monospace note are the only things kept from that first pass —
/// structural/typographic choices, not color-theme ones.
struct ExtendedPageView: View {
    @Binding var entry: DiaryEntry
    let quote: Quote?
    var onTearOff: (() -> Void)? = nil
    var onPrevDay: (() -> Void)? = nil
    var onNextDay: (() -> Void)? = nil
    var onJumpToToday: (() -> Void)? = nil

    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var isEditingNote = false
    @FocusState private var noteFocused: Bool

    /// Same inline-markdown rendering as `MemoBox` (bold/italic/strikethrough/
    /// code/links) — kept here rather than routing through MemoBox itself
    /// since this pane also needs the monospace font and the day-nav row
    /// MemoBox doesn't have.
    private var renderedNote: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: entry.journalText, options: options)) ?? AttributedString(entry.journalText)
    }

    /// The calendar side stays fixed — literally the same `DayPageHeader`
    /// component the compact page uses, at the same width, unchanged as
    /// the window grows. Only the task/note pane grows to fill whatever
    /// extra width shows up. Earlier passes tried a percentage split and a
    /// left-aligned rebuild of the header; both redrew the calendar itself,
    /// which is exactly what the user said not to do ("the calendar stay
    /// the same") — reusing the real component instead of reimplementing
    /// it sidesteps that class of mistake entirely.
    var body: some View {
        HStack(spacing: 0) {
            leftPane
                .frame(width: 400)
            HairlineDivider()
                .frame(width: 1)
            rightPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity)
        .background(DS.paper)
    }

    // MARK: - Left pane (unchanged compact header + idiom, same order/
    // components as compact mode: header, then the quote card right under
    // it — "the idiom is on the right [pane]?! it should be under the
    // calendar" was this assistant misreading its own earlier instruction;
    // fixed by literally reusing DailyQuoteView here too, same as
    // DayPageHeader above.)

    private var leftPane: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                DayPageHeader(date: entry.date, language: language)
                HairlineDivider()
                // The quote card's own text is left-aligned internally
                // (matches compact mode's QuoteCardView exactly), but as a
                // block it's centered under the numeral above rather than
                // hugging the pane's left edge — otherwise it visually
                // orphans itself from the centered numeral it sits under.
                DailyQuoteView(date: entry.date, quote: quote)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
        }
    }

    // MARK: - Right pane

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            taskSection
            HairlineDivider()
            noteSection
            tearButton
            Spacer(minLength: 4)
        }
        .padding(32)
        // Extra top clearance: the corner icon cluster (Today/Archive)
        // floats over the window's actual top-right corner, which sits
        // inside this pane's top edge.
        .padding(.top, 20)
        // Caps the reading/editing column at a sane width even though the
        // pane itself is 80% of a wide window — otherwise task rows and the
        // note just stretch edge to edge with a huge gap between the title
        // and the trailing icons, which looks broken, not spacious.
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var taskSection: some View {
        ExtendedTaskSection(language: language)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Localizer.t("メモ", "NOTE", language: language))
                    .font(DS.smallCaption)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Text(Localizer.t("Markdown対応", "Markdown", language: language))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Menu {
                    Button(Localizer.t("メモを消去", "Clear note", language: language), role: .destructive) {
                        entry.journalText = ""
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }

            Group {
                if entry.journalText.isEmpty || isEditingNote {
                    TextEditor(text: $entry.journalText)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .focused($noteFocused)
                        // Only grabs focus when the preview is tapped
                        // (isEditingNote flips true) — never on mere
                        // appearance, which stole keystrokes typed
                        // anywhere else in the app the instant an empty
                        // note scrolled into view.
                        .onChange(of: isEditingNote) { _, editing in
                            if editing { noteFocused = true }
                        }
                        .onChange(of: noteFocused) { _, focused in
                            if !focused { isEditingNote = false }
                        }
                } else {
                    ScrollView {
                        Text(renderedNote)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { isEditingNote = true }
                }
            }
            .padding(6)
            .frame(height: 220)
            .overlay(Rectangle().stroke(DS.hairline, lineWidth: 1))

            HStack {
                Button {
                    onJumpToToday?()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(onJumpToToday == nil)

                Spacer()

                Button {
                    onPrevDay?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(onPrevDay == nil ? Color.secondary.opacity(0.3) : Color.secondary)
                .disabled(onPrevDay == nil)

                Button {
                    onNextDay?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(onNextDay == nil ? Color.secondary.opacity(0.3) : Color.secondary)
                .disabled(onNextDay == nil)
            }
        }
    }

    private var tearButton: some View {
        Group {
            if let onTearOff {
                Button(action: onTearOff) {
                    HStack {
                        Spacer()
                        Text(Localizer.t("今日を切り取る", "TEAR OFF TODAY", language: language))
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(Color.primary, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Task list for the extended pane — same `TaskStore` and rules as the
/// compact `TaskListView` (drag reorder scoped to active/done group, click
/// title to edit, expand for checklist/notes/defer), with a dot-grid drag
/// handle instead of the compact page's hamburger icon (a structural
/// choice kept from the original concept — not color-theme related).
private struct ExtendedTaskSection: View {
    let language: AppLanguage

    @Environment(TaskStore.self) private var store
    @State private var newTaskText = ""
    @State private var expandedTaskIDs: Set<UUID> = []
    @State private var showDeferred = false
    @FocusState private var fieldFocused: Bool

    private var visibleTasks: [TaskItem] { store.tasks.filter { !isDeferred($0) } }
    private var activeTasks: [TaskItem] { visibleTasks.filter { !$0.isDone }.sorted { $0.order < $1.order } }
    private var doneTasks: [TaskItem] { visibleTasks.filter { $0.isDone }.sorted { $0.order < $1.order } }
    private var deferredTasks: [TaskItem] {
        store.tasks.filter { isDeferred($0) }.sorted { ($0.deferDate ?? .distantFuture) < ($1.deferDate ?? .distantFuture) }
    }

    private func isDeferred(_ task: TaskItem) -> Bool {
        guard !task.isDone, let deferDate = task.deferDate else { return false }
        return deferDate > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Localizer.t("やること", "TASKS", language: language))
                    .font(DS.smallCaption)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Spacer()
                Button { fieldFocused = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.primary.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

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

            if !deferredTasks.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showDeferred.toggle() }
                } label: {
                    Text(Localizer.t("＋\(deferredTasks.count)件 予定あり", "+\(deferredTasks.count) scheduled", language: language))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                if showDeferred {
                    ForEach(deferredTasks) { task in row(task) }
                }
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        ExtendedTaskRow(task: task, language: language, isExpanded: expandedTaskIDs.contains(task.id)) {
            if expandedTaskIDs.contains(task.id) {
                expandedTaskIDs.remove(task.id)
            } else {
                expandedTaskIDs.insert(task.id)
            }
        }
    }

    private func addTask() {
        store.add(title: newTaskText)
        newTaskText = ""
        fieldFocused = true
    }
}

private struct ExtendedTaskRow: View {
    let task: TaskItem
    let language: AppLanguage
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @Environment(TaskStore.self) private var store
    @State private var newStepText = ""
    @State private var showDatePicker = false
    @State private var pendingDeferDate = Date()
    @FocusState private var stepFieldFocused: Bool

    private var titleBinding: Binding<String> {
        Binding(get: { task.title }, set: { var t = task; t.title = $0; store.update(t) })
    }
    private var notesBinding: Binding<String> {
        Binding(get: { task.notes }, set: { var t = task; t.notes = $0; store.update(t) })
    }

    /// Same relative feedback as the compact page's `TaskRow` — "in N
    /// days" while hidden, "Today" the day it reappears, "Overdue" (red)
    /// if it arrived and is still undone.
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

    private func clearDefer() {
        var updated = task
        updated.deferDate = nil
        store.update(updated)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) { store.toggleDone(task.id) }
                } label: {
                    Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                        .font(.system(size: 13))
                        .foregroundStyle(task.isDone ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)

                if task.isDone {
                    Text(task.title)
                        .font(.system(size: 13))
                        .strikethrough(true)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("", text: titleBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }

                Spacer()

                DotGridHandle()
                    .draggable(task.id.uuidString)

                Button { store.delete(task.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .dropDestination(for: String.self) { items, _ in
                guard let idString = items.first, let draggedId = UUID(uuidString: idString) else { return false }
                withAnimation(.easeInOut(duration: 0.15)) { store.move(draggedId: draggedId, to: task.id) }
                return true
            }

            HStack(spacing: 10) {
                Spacer()
                if let badge = deferBadge {
                    Text(badge.text)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(badge.isOverdue ? Color.red : Color.secondary)
                }
                if !task.checklist.isEmpty {
                    Text(verbatim: "\(task.checklist.filter { $0.isDone }.count)/\(task.checklist.count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }

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
                            Spacer()
                            Button { store.deleteChecklistItem(taskId: task.id, itemId: item.id) } label: {
                                Image(systemName: "xmark").font(.system(size: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
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
                Button(action: clearDefer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
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
    }
}

/// A small 2×3 dot-grid drag handle, matching the concept's icon — no exact
/// SF Symbol match, so built directly rather than approximated with the
/// wrong glyph (e.g. a hamburger icon).
private struct DotGridHandle: View {
    var body: some View {
        VStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 2.5) {
                    ForEach(0..<2, id: \.self) { _ in
                        Circle().fill(Color.secondary).frame(width: 2.5, height: 2.5)
                    }
                }
            }
        }
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
    }
}
