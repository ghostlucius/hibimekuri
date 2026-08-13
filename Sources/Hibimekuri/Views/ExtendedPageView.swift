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
    /// Passed down from `EditablePageView` so the task list, note box, and
    /// tear button here are recognized as the same elements as their
    /// compact-mode counterparts — see the doc comment on
    /// `EditablePageView.transitionNamespace`.
    var transitionNamespace: Namespace.ID

    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var isEditingNote = false
    @FocusState private var noteFocused: Bool

    /// Full block Markdown (headings, lists, blockquotes, code — see
    /// BlockMarkdownRenderer) rather than MemoBox's inline-only rendering:
    /// this pane has the room for it, the compact memo doesn't.
    private var renderedNote: AttributedString {
        BlockMarkdownRenderer.render(entry.journalText)
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
        VStack(alignment: .leading, spacing: 24) {
            taskSection
                .matchedGeometryEffect(id: "tasks", in: transitionNamespace)
            HairlineDivider()
            noteSection
                .matchedGeometryEffect(id: "note", in: transitionNamespace)
            tearButton
                .matchedGeometryEffect(id: "tearButton", in: transitionNamespace)
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
        //
        // Both constraints belong in one `frame` call, not two chained
        // ones — chaining `.frame(maxWidth: 760)` and then
        // `.frame(maxHeight: .infinity)` on separate calls only let the
        // *outer* frame report a flexible height up to its own parent; it
        // never fed that extra height back down into the VStack, so the
        // VStack (and everything in it, including the note box below) just
        // sized to its own intrinsic content height and got top-aligned
        // inside the leftover space — which is exactly the dead space
        // below "TEAR OFF TODAY" on a tall window. Setting both in a
        // single call proposes the full available height to the VStack
        // itself, so its one flexible child (the note box, see noteSection
        // below) can actually grow into it.
        .frame(maxWidth: 760, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
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
                Spacer()
                Menu {
                    Button(Localizer.t("メモを消去", "Clear note", language: language), role: .destructive) {
                        entry.journalText = ""
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                // SwiftUI draws its own disclosure arrow next to any custom
                // Menu label by default (Menu.menuIndicator(.visible), the
                // default) — that's what was showing up glued onto the
                // ellipsis icon. This is the only supported way to turn it
                // off; the icon alone already reads as "more options".
                .menuIndicator(.hidden)
                .help(Localizer.t("その他のオプション", "More options", language: language))
                .accessibilityLabel(Localizer.t("その他のオプション", "More options", language: language))
            }

            Group {
                if entry.journalText.isEmpty || isEditingNote {
                    TextEditor(text: $entry.journalText)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .focused($noteFocused)
                        .accessibilityLabel(Localizer.t("メモ", "Note", language: language))
                        // Only grabs focus when isEditingNote flips true
                        // (tapping the rendered preview below) — never on
                        // mere appearance, which stole keystrokes typed
                        // anywhere else in the app the instant an empty
                        // note scrolled into view. initial: true is still
                        // needed: this TextEditor is a brand-new view the
                        // moment isEditingNote becomes true (that's what
                        // creates it), so without initial:true this
                        // onChange's first evaluation IS that already-true
                        // state, and onChange never fires on first
                        // appearance by default — the focus grab silently
                        // never ran, requiring a second click to focus the
                        // now-visible editor manually.
                        .onChange(of: isEditingNote, initial: true) { _, editing in
                            noteFocused = editing
                        }
                        .onChange(of: noteFocused) { _, focused in
                            if !focused { isEditingNote = false }
                        }
                } else {
                    Button {
                        isEditingNote = true
                    } label: {
                        ScrollView {
                            Text(renderedNote)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Localizer.t("メモを編集", "Edit note", language: language))
                }
            }
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

    @Environment(TaskStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var newTaskText = ""
    // Single-optional, not a Set — only one task is ever open at a time.
    @State private var expandedTaskID: UUID?
    @State private var selectedTaskID: UUID?
    @State private var showDeferred = false
    @FocusState private var fieldFocused: Bool

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
        let collapsedRowHeight: CGFloat = 34
        let expandedExtra: CGFloat = 180
        let hasExpanded = expanded.map { id in group.contains { $0.id == id } } ?? false
        return CGFloat(group.count) * collapsedRowHeight + (hasExpanded ? expandedExtra : 0)
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
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                        .overlay(Circle().stroke(DS.text.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Localizer.t("タスクを追加", "Add a task", language: language))
            }

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
                    ForEach(deferredTasks) { task in row(task) }
                }
            }
        }
        // Things-style "click anywhere else closes/deselects it" — see
        // TaskListView.swift's identical use of this notification for the
        // full rationale.
        .onReceive(NotificationCenter.default.publisher(for: .taskInteractionReset)) { _ in
            selectedTaskID = nil
            expandedTaskID = nil
        }
    }

    private func row(_ task: TaskItem) -> some View {
        ExtendedTaskRow(
            task: task,
            language: language,
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

private struct ExtendedTaskRow: View {
    let task: TaskItem
    let language: AppLanguage
    let isExpanded: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onSelect: () -> Void

    @Environment(TaskStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var newStepText = ""
    @State private var showDatePicker = false
    @State private var pendingDeferDate = Date()
    @State private var isEditingTitle = false
    @FocusState private var stepFieldFocused: Bool
    @FocusState private var titleFocused: Bool

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
            // One line, not two — the badge/checklist-count used to sit on
            // their own right-aligned row below the title, which is why
            // "Overdue" never lined up with the task the way it does in
            // the compact layout even though extended mode has more room,
            // not less. Same single-line shape as the compact TaskRow now.
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
                if !task.checklist.isEmpty {
                    Text(verbatim: "\(task.checklist.filter { $0.isDone }.count)/\(task.checklist.count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
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
            // Double-click always opens (never toggles closed) — closing
            // only happens by clicking elsewhere (see taskInteractionReset).
            .onTapGesture(count: 2) {
                startRename()
            }
            .onTapGesture(count: 1) {
                guard !isEditingTitle else { return }
                onSelect()
            }
            // Dragging is handled entirely by the enclosing
            // AppKitTaskTable's real NSTableView machinery now.

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    MarkdownNotesField(text: notesBinding, placeholder: Localizer.t("メモ", "Notes", language: language))

                    deferRow

                    ForEach(task.checklist) { item in
                        HStack(spacing: 6) {
                            Button {
                                store.toggleChecklistItem(taskId: task.id, itemId: item.id)
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.square" : "square")
                                    .font(.system(size: 11))
                                    .foregroundStyle(item.isDone ? DS.text : DS.textSecondary)
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.isDone
                                ? Localizer.t("ステップを未完了にする", "Mark step incomplete", language: language)
                                : Localizer.t("ステップを完了", "Complete step", language: language))
                            Text(item.title)
                                .font(.system(size: 12))
                                .strikethrough(item.isDone)
                            Spacer()
                            Button { store.deleteChecklistItem(taskId: task.id, itemId: item.id) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Localizer.t("ステップを削除", "Delete step", language: language))
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
            } else if isEditingTitle {
                TextField("", text: titleBinding)
                    .textFieldStyle(.plain)
                    .focused($titleFocused)
                    .accessibilityLabel(Localizer.t("タスク名", "Task title", language: language))
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(task.title)
                .accessibilityAction(named: Localizer.t("詳細を表示", "Show details", language: language)) {
                    onOpen()
                }
                .accessibilityAction(named: Localizer.t("名前を変更", "Rename task", language: language)) {
                    startRename()
                }
            }
        }
        .font(.system(size: 13))
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                isEditingTitle = false
            }
        }
    }

    private func startRename() {
        onOpen()
        if !task.isDone {
            isEditingTitle = true
        }
    }
}
