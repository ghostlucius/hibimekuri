import SwiftUI

/// Markdown-aware memo/note field. Editing is always plain text (no rich
/// editor risk — this codebase has already been bitten once by gesture/focus
/// conflicts around TextEditor, see the "Known SwiftUI traps" note in
/// requirements.md); markdown only renders in a separate read-only preview
/// shown when the field isn't focused, using SwiftUI's built-in inline
/// markdown parsing (bold/italic/strikethrough/code/links) rather than a
/// hand-built block-level renderer.
struct MemoBox: View {
    @Binding var text: String
    var isEditable: Bool = true
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private var renderedMarkdown: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    /// Read-only pages always show the rendered preview (no reason to ever
    /// show a disabled editor there); editable pages show the plain-text
    /// editor while empty (so typing starts immediately, placeholder
    /// visible) or while actively focused, and the rendered preview
    /// otherwise.
    private var showEditor: Bool {
        isEditable && (text.isEmpty || isEditing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Localizer.t("メモ", "MEMO", language: language))
                    .font(DS.smallCaption)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Spacer()
                if isEditable {
                    Text(Localizer.t("Markdown対応", "Markdown", language: language))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty && isEditable {
                    Text(Localizer.t("今日の振り返りを書く…", "Write today's reflection…", language: language))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

                if showEditor {
                    // TextEditor has its own fixed ~5pt leading inset baked
                    // into NSTextView (lineFragmentPadding) that SwiftUI's
                    // .padding() doesn't touch — cancel it with a negative
                    // pad so the real cursor lands at the same origin as
                    // the placeholder/preview Text, instead of guessing
                    // matching-but-different padding values on each.
                    TextEditor(text: $text)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                        .padding(.leading, -5)
                        .frame(minHeight: 70)
                        // Only grabs focus in response to the tap below
                        // (isEditing flipping true) — never on mere
                        // appearance, which was stealing keystrokes typed
                        // anywhere else in the app the instant an empty
                        // note scrolled into view.
                        .onChange(of: isEditing) { _, editing in
                            if editing { isFocused = true }
                        }
                        .onChange(of: isFocused) { _, focused in
                            if !focused { isEditing = false }
                        }
                } else {
                    Text(renderedMarkdown)
                        .font(.system(size: 12))
                        .foregroundStyle(isEditable ? .primary : .secondary)
                        .frame(minHeight: 70, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isEditable else { return }
                            isEditing = true
                        }
                }
            }
            .padding(6)
            .overlay(
                Rectangle()
                    .stroke(DS.hairline, lineWidth: 1)
            )
        }
    }
}
