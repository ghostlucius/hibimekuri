import SwiftUI

/// Markdown-aware memo/note field. Editing is always plain text (no rich
/// editor risk — this codebase has already been bitten once by gesture/focus
/// conflicts around TextEditor, see the "Known SwiftUI traps" note in
/// requirements.md); markdown only renders in a separate read-only preview
/// shown when the field isn't focused, using the same block renderer as the
/// extended layout's NOTE panel (BlockMarkdownRenderer — headings, lists,
/// blockquotes, code, plus inline bold/italic/strikethrough/code/links).
/// Originally scoped to inline-only here, on the theory that a small memo
/// box didn't need full block structure — reversed once raw "# heading"
/// text sitting unrendered turned out to just look broken rather than
/// "appropriately simple".
struct MemoBox: View {
    @Binding var text: String
    var isEditable: Bool = true
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private var renderedMarkdown: AttributedString {
        BlockMarkdownRenderer.render(text)
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
            Text(Localizer.t("メモ", "MEMO", language: language))
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

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
                        // Only grabs focus in response to isEditing flipping
                        // true (tapping the rendered preview below) — never
                        // on mere appearance, which was stealing keystrokes
                        // typed anywhere else in the app the instant an
                        // empty note scrolled into view. initial: true is
                        // still required, though: this TextEditor is a
                        // brand-new view the moment it exists at all (the
                        // tap that set isEditing=true is what created it in
                        // the first place), so without initial:true this
                        // onChange's very first evaluation IS that
                        // already-true state — and onChange never fires on
                        // a view's first appearance by default, so the
                        // focus grab silently never ran. That's why it took
                        // a second, separate click (to focus the now-
                        // visible-but-unfocused editor manually) instead of
                        // the tap itself landing the cursor.
                        .onChange(of: isEditing, initial: true) { _, editing in
                            isFocused = editing
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
