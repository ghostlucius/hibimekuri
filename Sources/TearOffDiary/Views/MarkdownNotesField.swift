import SwiftUI

/// A task's inline notes field: renders as markdown by default, switches to
/// a raw editable field when tapped, and back to rendered once it loses
/// focus — the same click-to-edit/lose-focus-to-preview pattern as the
/// memo/note fields (MemoBox.swift, ExtendedPageView.swift), just without
/// their box chrome since this sits inline inside a task row. Shared here
/// rather than duplicated because the compact TaskListView and the
/// ExtendedTaskRow both use it identically.
struct MarkdownNotesField: View {
    @Binding var text: String
    var placeholder: String

    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private var rendered: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    var body: some View {
        Group {
            if text.isEmpty || isEditing {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    // initial: true matters here — this TextField only
                    // exists once isEditing is already true (it's the
                    // conditional branch that creates it), so without
                    // initial:true this onChange's "first appearance" IS
                    // that already-true state, and per SwiftUI's documented
                    // behavior onChange never fires on first appearance by
                    // default — the focus grab would silently never run,
                    // leaving a visible-but-unfocused field until a second,
                    // separate click focused it manually.
                    .onChange(of: isEditing, initial: true) { _, editing in
                        isFocused = editing
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { isEditing = false }
                    }
            } else {
                Button {
                    isEditing = true
                } label: {
                    Text(rendered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Localizer.t("メモを編集", "Edit notes", language: language))
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
}
