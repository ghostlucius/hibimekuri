import SwiftUI

/// Task notes share the main note editor: formatted text is the default,
/// Markdown remains available when literal syntax is needed, and Focus Mode
/// edits the same binding without changing task interaction state.
struct MarkdownNotesField: View {
    @Binding var text: String
    var placeholder: String
    var sectionTitle: String? = nil
    var minEditorHeight: CGFloat = 96
    var maxEditorHeight: CGFloat? = 180
    var pageDate: Date? = nil

    @Environment(FocusModeController.self) private var focusMode
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var noteMode: NoteEditorMode = .formatted

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let sectionTitle {
                    Text(sectionTitle)
                        .font(DS.smallCaption)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }
                Spacer()

                Button {
                    focusMode.enter(editing: $text, from: pageDate)
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

            ZStack(alignment: .topLeading) {
                MarkdownRichNoteEditor(
                    journalText: $text,
                    mode: noteMode,
                    themePalette: ThemeManager.shared.currentPalette
                )
                .accessibilityLabel(placeholder)

                if text.isEmpty {
                    // Align the prompt with the editor real first line.
                    // The former extra vertical padding put its glyphs
                    // noticeably below the insertion caret.
                    Text(placeholder)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: minEditorHeight, maxHeight: maxEditorHeight)
            .padding(5)
            .overlay(Rectangle().stroke(DS.hairline, lineWidth: 1))
        }
    }
}
