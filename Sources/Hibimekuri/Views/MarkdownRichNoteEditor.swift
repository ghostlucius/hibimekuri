import SwiftUI

/// Hosts both note editors — formatted (WYSIWYG, `RichNoteEditor`) and raw
/// Markdown (`PlainMarkdownEditor`, plain text) — mounted conditionally,
/// one at a time, by `mode`.
///
/// An always-mounted, opacity-crossfaded version (both editors present
/// simultaneously, only one hit-testable) was tried first, on the theory
/// that conditional mounting would lose state on every mode switch the way
/// it did for the compact/extended layout transition elsewhere in this
/// codebase (see `EditablePageView`'s doc comments). That theory doesn't
/// actually apply here, though: unlike that case, the real editing state
/// (`formattedText`, `journalText`) already lives in *this* view, one
/// level above either child editor — so conditionally mounting the
/// children loses nothing. And always-mounting them cost something real:
/// found, by hand, that with two real `TextEditor`s simultaneously present
/// in the same `ZStack` (one merely hidden via opacity/hit-testing, still
/// part of the key-view loop), pressing Return silently produced a space
/// instead of a new line — confirmed as specific to this app, not a
/// testing artifact, by reproducing it with `System Events` while the
/// exact same synthetic keystroke worked correctly in TextEdit. Only one
/// editor mounted at a time removes whatever that conflict was.
///
/// Only `formattedText` needs syncing against `journalText` — the
/// Markdown editor writes `journalText` directly (it's already plain
/// Markdown, no translation needed), so there's only one round trip to
/// keep stable, not two.
///
/// Two guard flags, one per direction — necessary because a single flag
/// covering only the formatted→journalText direction left a mirror-image
/// bug in the other one: typing in Markdown mode still triggered the
/// journalText→formattedText reparse, and *that* reparse's own resulting
/// `formattedText` change triggered formattedText's `onChange` right back,
/// serializing the (Markdown-parser-collapsed) result and overwriting
/// `journalText` with it — so a newline just typed in Markdown mode
/// (confirmed correctly written in the instant right after pressing
/// Return) was gone by the very next keystroke.
///
/// Each flag resets on the *next run-loop tick*
/// (`DispatchQueue.main.async`), not synchronously right after its write.
/// A synchronous reset was tried first and didn't actually fix the bug
/// above — confirmed by testing, not assumed: the guard has to still be
/// set at the moment the *other* property's `onChange` fires, and that
/// isn't guaranteed to happen within the same synchronous call stack as
/// the write that triggered it, only reliably by the next cycle. (A
/// different, single *shared* flag elsewhere in this app was reset this
/// same async way and caused a real bug — a rapid edit landing before the
/// reset had run got silently dropped. That doesn't apply here: these two
/// flags are narrow and direction-specific, so one resetting late doesn't
/// block the *other* direction's next keystroke, only a same-direction
/// echo — which is exactly what should be blocked.)
struct MarkdownRichNoteEditor: View {
    @Binding var journalText: String
    var mode: NoteEditorMode
    var themePalette: ThemePalette

    @State private var formattedText = AttributedString("")
    @State private var hasLoaded = false
    @State private var isEditingFormatted = false
    @State private var isEditingMarkdown = false

    var body: some View {
        Group {
            if mode == .formatted {
                RichNoteEditor(text: $formattedText, themePalette: themePalette)
            } else {
                PlainMarkdownEditor(text: $journalText)
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            formattedText = NoteMarkdown.parse(journalText)
        }
        .onChange(of: formattedText) { _, newValue in
            guard !isEditingMarkdown else { return }
            let serialized = NoteMarkdown.serialize(newValue)
            guard serialized != journalText else { return }
            isEditingFormatted = true
            journalText = serialized
            DispatchQueue.main.async { isEditingFormatted = false }
        }
        .onChange(of: journalText) { _, newValue in
            guard !isEditingFormatted else { return }
            let reparsed = NoteMarkdown.parse(newValue)
            guard formattedText != reparsed else { return }
            isEditingMarkdown = true
            formattedText = reparsed
            DispatchQueue.main.async { isEditingMarkdown = false }
        }
    }
}

/// Markdown mode deliberately uses a plain `String` editor so literal source
/// text stays literal, including list and task-list markers.
private struct PlainMarkdownEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 12, design: .monospaced))
            .scrollContentBackground(.hidden)
            .autocorrectionDisabled()
    }
}
