import SwiftUI

/// The wide-window layout — a real redesigned two-pane view, not the
/// compact page centered on more background (that was tried first and
/// rejected). Left pane: header, numeral, almanac column, compact mini
/// calendars. Right pane: tasks, note, idiom, tear-off button, with more
/// room to breathe than the compact page's single column.
///
/// Styled through the same `DS`/`ThemeManager` palette as the compact page,
/// not a one-off green theme nobody could select (an early pass invented
/// one; reverted per the user 2026-08-02, before the real theme system
/// existed). The dot-grid drag handle and monospace note are the only
/// things kept from that first pass — structural/typographic choices, not
/// color-theme ones.
struct ExtendedPageView: View {
    @Binding var entry: DiaryEntry
    let quote: Quote?
    var onTearOff: (() -> Void)? = nil
    var onPrevDay: (() -> Void)? = nil
    var onNextDay: (() -> Void)? = nil
    var onJumpToToday: (() -> Void)? = nil

    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @Environment(FocusModeController.self) private var focusMode
    @State private var noteMode: NoteEditorMode = .formatted

    /// The calendar side stays fixed — literally the same `DayPageHeader`
    /// component the compact page uses, at the same width, unchanged as
    /// the window grows. Only the task/note pane grows to fill whatever
    /// extra width shows up. Earlier passes tried a percentage split and a
    /// left-aligned rebuild of the header; both redrew the calendar itself,
    /// which is exactly what the user said not to do ("the calendar stay
    /// the same") — reusing the real component instead of reimplementing
    /// it sidesteps that class of mistake entirely.
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leftPane
                .frame(width: 400)
            HairlineDivider()
                .frame(width: 1)
            rightPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity)
        .background(DS.paper)
        .foregroundStyle(DS.text)
    }

    // MARK: - Left pane (unchanged compact header + idiom, same order/
    // components as compact mode: header, then the quote card right under
    // it — "the idiom is on the right [pane]?! it should be under the
    // calendar" was this assistant misreading its own earlier instruction;
    // fixed by literally reusing DailyQuoteView here too, same as
    // DayPageHeader above.)

    private var leftPane: some View {
        // GeometryReader + ScrollView + a `minHeight` tied to the reader's
        // own height is the standard SwiftUI recipe for "fill the visible
        // area when content is short, but still scroll if it overflows" —
        // contained entirely within this one property, not threaded across
        // files. A bare `.frame(maxHeight: .infinity)` on the illustration
        // wouldn't work here on its own: a ScrollView proposes *unbounded*
        // height to its content so it can measure a natural scrollable
        // size, so a flexible child inside it never gets a real target to
        // grow into (the same class of layout trap as the note box and the
        // rightPane frame-chaining bug below, just a different shape).
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    DayPageHeader(date: entry.date, language: language)
                    HairlineDivider()
                    // Left-aligned to match compact mode's QuoteCardView
                    // exactly — centering it under the numeral (tried
                    // previously) made it inconsistent with the compact
                    // page, which was the more important match to keep.
                    DailyQuoteView(date: entry.date, quote: quote)
                    // Every theme has its own recolor of the same mountain
                    // vector — see DiaryIllustrationView. Fills whatever
                    // space is left below the quote card, cropped (not
                    // letterboxed) so it always covers the remaining
                    // rectangle edge to edge.
                    DiaryIllustrationView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(20)
                .frame(minHeight: proxy.size.height)
            }
        }
    }

    // MARK: - Right pane

    private var rightPane: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 24) {
                taskSection(maxListHeight: taskListMaxHeight(for: proxy.size.height))
                HairlineDivider()
                noteSection
                tearButton
            }
            .padding(32)
            .padding(.top, 20)
            .frame(maxWidth: 760, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    /// Leaves the calendar and main note their guaranteed room first. The
    /// task list can grow within this allocation and then scrolls on its
    /// own, instead of extending the entire two-pane page beyond the window.
    private func taskListMaxHeight(for availableHeight: CGFloat) -> CGFloat {
        let reservedHeight: CGFloat = 465
        return min(360, max(120, availableHeight - reservedHeight))
    }

    private func taskSection(maxListHeight: CGFloat) -> some View {
        ExtendedTaskSection(
            language: language,
            maxListHeight: maxListHeight,
            pageDate: entry.date
        )
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Localizer.t("メモ", "NOTE", language: language))
                    .font(DS.smallCaption)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Spacer()
                Button {
                    focusMode.enter(editing: $entry.journalText, from: entry.date)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(Localizer.t("集中モード", "Focus Mode", language: language))
                .accessibilityLabel(Localizer.t("集中モードで開く", "Open in Focus Mode", language: language))

                Button {
                    noteMode = (noteMode == .formatted) ? .markdown : .formatted
                } label: {
                    // Reflects the mode you'd switch *to*, matching how a
                    // toggle control's icon usually reads — showing "M↓"
                    // while already in Markdown mode would just repeat
                    // what's already on screen.
                    Image(systemName: noteMode == .formatted ? "textformat" : "doc.richtext")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(noteMode == .formatted
                    ? Localizer.t("Markdownで編集", "Switch to Markdown", language: language)
                    : Localizer.t("整形されたテキストで表示", "Switch to formatted text", language: language))
                .accessibilityLabel(noteMode == .formatted
                    ? Localizer.t("Markdownで編集", "Switch to Markdown", language: language)
                    : Localizer.t("整形されたテキストで表示", "Switch to formatted text", language: language))
            }

            MarkdownRichNoteEditor(journalText: $entry.journalText, mode: noteMode, themePalette: ThemeManager.shared.currentPalette)
            .padding(6)
            // Was a fixed 220pt regardless of window height — the one
            // deliberately flexible element in the pane now, so a tall
            // window's extra height goes into more writing room instead of
            // sitting empty below the tear-off button.
            .frame(minHeight: 220, maxHeight: .infinity)
            .overlay(Rectangle().stroke(DS.hairline, lineWidth: 1))

            HStack {
                Button {
                    onJumpToToday?()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(onJumpToToday == nil)
                .help(Localizer.t("今日にジャンプ", "Jump to today", language: language))
                .accessibilityLabel(Localizer.t("今日にジャンプ", "Jump to today", language: language))

                Spacer()

                Button {
                    onPrevDay?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(onPrevDay == nil ? DS.textSecondary.opacity(0.3) : DS.textSecondary)
                .disabled(onPrevDay == nil)
                .accessibilityLabel(Localizer.t("前の日", "Previous day", language: language))

                Button {
                    onNextDay?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(onNextDay == nil ? DS.textSecondary.opacity(0.3) : DS.textSecondary)
                .disabled(onNextDay == nil)
                .accessibilityLabel(Localizer.t("次の日", "Next day", language: language))
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
                    // See OnboardingView's identical fix: Spacers paint
                    // nothing, so without this only the Text label was
                    // actually clickable, not the full button width.
                    .contentShape(Rectangle())
                    .overlay(Rectangle().stroke(DS.text, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Task list for the extended pane — same `TaskStore` and Things-style
/// interaction as the compact `TaskListView`, including its real
/// `AppKitTaskTable`-backed drag-to-reorder — see TaskListView.swift for
/// the full story of why a direct `NSTableView` wrapper instead of
/// SwiftUI's own `List`/`.draggable`.
private struct ExtendedTaskSection: View {
    let language: AppLanguage
    let maxListHeight: CGFloat
    let pageDate: Date

    @Environment(TaskStore.self) private var store
    @Environment(TaskInteractionController.self) private var interaction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var newTaskText = ""
    // Single-optional, not a Set — only one task is ever open at a time.
    @State private var showDeferred = false
    @FocusState private var fieldFocused: Bool

    private var expandedTaskID: UUID? { interaction.expandedTask(on: pageDate) }

    private var visibleTasks: [TaskItem] { store.tasks.filter { $0.archivedAt == nil && !isDeferred($0) } }
    private var activeTasks: [TaskItem] { visibleTasks.filter { !$0.isDone }.sorted { $0.order < $1.order } }
    private var doneTasks: [TaskItem] { visibleTasks.filter { $0.isDone }.sorted { $0.order < $1.order } }
    private var deferredTasks: [TaskItem] {
        store.tasks.filter { $0.archivedAt == nil && isDeferred($0) }.sorted { ($0.deferDate ?? .distantFuture) < ($1.deferDate ?? .distantFuture) }
    }

    private func isDeferred(_ task: TaskItem) -> Bool {
        guard !task.isDone, let deferDate = task.deferDate else { return false }
        return deferDate > Calendar.current.startOfDay(for: Date())
    }

    /// See TaskListView.swift's identical helper for the full rationale.
    private func estimatedHeight(for group: [TaskItem], expanded: UUID?) -> CGFloat {
        let collapsedRowHeight: CGFloat = 28
        let expandedExtra: CGFloat = 180
        let hasExpanded = expanded.map { id in group.contains { $0.id == id } } ?? false
        return CGFloat(group.count) * collapsedRowHeight + (hasExpanded ? expandedExtra : 0)
    }

    private var taskListContentHeight: CGFloat {
        var height: CGFloat = 28
        if !activeTasks.isEmpty { height += estimatedHeight(for: activeTasks, expanded: expandedTaskID) + 10 }
        if !doneTasks.isEmpty { height += estimatedHeight(for: doneTasks, expanded: expandedTaskID) + 10 }
        if !deferredTasks.isEmpty {
            height += 20
            if showDeferred { height += CGFloat(deferredTasks.count) * 34 + 10 }
        }
        return height
    }

    /// The viewport is based on collapsed rows only. Opening a task must
    /// never make the task panel grow and push the rest of the page away.
    private var collapsedTaskListContentHeight: CGFloat {
        var height: CGFloat = 28
        if !activeTasks.isEmpty { height += estimatedHeight(for: activeTasks, expanded: nil) + 10 }
        if !doneTasks.isEmpty { height += estimatedHeight(for: doneTasks, expanded: nil) + 10 }
        if !deferredTasks.isEmpty { height += 20 }
        return height
    }

    private var taskListViewportHeight: CGFloat {
        min(maxListHeight, max(160, collapsedTaskListContentHeight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localizer.t("やること", "TASKS", language: language))
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            ScrollView(.vertical, showsIndicators: taskListContentHeight > taskListViewportHeight) {
                VStack(alignment: .leading, spacing: 10) {
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

                    if !deferredTasks.isEmpty {
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { showDeferred.toggle() }
                        } label: {
                            Text(Localizer.t("＋\(deferredTasks.count)件 予定あり", "+\(deferredTasks.count) scheduled", language: language))
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)

                        if showDeferred {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(deferredTasks) { task in row(task) }
                            }
                        }
                    }
                }
            }
            .frame(height: taskListViewportHeight)
        }
        // Things-style "click anywhere else closes/deselects it" — see
        // TaskListView.swift's identical use of this notification for the
        // full rationale.
        .onReceive(NotificationCenter.default.publisher(for: .taskInteractionReset)) { _ in
            interaction.close()
        }
        // The dismissal target belongs only to the task section, never the
        // rest of the extended page. Its background placement leaves task
        // controls and the Markdown editor fully interactive.
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { closeExpandedTask() }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        ExtendedTaskRow(
            task: task,
            language: language,
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

private struct ExtendedTaskRow: View {
    let task: TaskItem
    let language: AppLanguage
    let pageDate: Date
    let isExpanded: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onSelect: () -> Void

    @Environment(TaskStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDatePicker = false
    @State private var pendingDeferDate = Date()
    @FocusState private var titleFocused: Bool

    /// See TaskRow's identical live lookup. Focus Mode removes this row
    /// while retaining its note binding, so a captured TaskItem could become
    /// stale after the first edit.
    private var currentTask: TaskItem {
        store.tasks.first(where: { $0.id == task.id }) ?? task
    }

    private var titleBinding: Binding<String> {
        Binding(get: { task.title }, set: { var t = task; t.title = $0; store.update(t) })
    }
    private var notesBinding: Binding<String> {
        Binding(get: { currentTask.notes }, set: { var t = currentTask; t.notes = $0; store.update(t) })
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
            // A single row keeps the due-date state aligned with its task in
            // both compact and extended layouts.
            HStack(spacing: 8) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) { store.toggleDone(task.id) }
                } label: {
                    Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                        .font(.system(size: 13))
                        .foregroundStyle(task.isDone ? DS.text : DS.textSecondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isDone
                    ? Localizer.t("タスクを未完了にする", "Mark task incomplete", language: language)
                    : Localizer.t("タスクを完了", "Complete task", language: language))

                titleView

                Spacer()

                if let badge = deferBadge {
                    Text(badge.text)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(badge.isOverdue ? Color.red : DS.textSecondary)
                }

                Button { store.delete(task.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Localizer.t("タスクを削除", "Delete task", language: language))
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
            // AppKitTaskTable's real NSTableView machinery now.

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
                Button(action: clearDefer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Localizer.t("日付を消去", "Clear date", language: language))
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

    /// Plain text until a double-click on the row starts a rename — see the
    /// compact TaskRow's identical rationale and fix in TaskListView.swift
    /// (deferred focus-grab + isExpanded-driven reset — confirmed via real
    /// click/drag testing to be a genuine race, not theoretical).
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
                    .focused($titleFocused)
                    .accessibilityLabel(Localizer.t("タスク名", "Task title", language: language))
                    .onAppear {
                        DispatchQueue.main.async { titleFocused = true }
                    }
            } else {
                Text(task.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(task.title)
                .accessibilityAction(named: Localizer.t("詳細を表示", "Show details", language: language)) {
                    onOpen()
                }
            }
        }
        .font(.system(size: 13))
    }
}
