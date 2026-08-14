import SwiftUI

/// Distraction-free journaling — the note fills the *entire app window*
/// (not a separate OS-level fullscreen/window), covering the calendar,
/// tasks, and even the corner Today/Archive icon cluster. `RootView` is
/// what actually shows this, as its own topmost overlay, so it can sit
/// above everything else regardless of which layout (compact/extended)
/// is active underneath.
struct FocusModeView: View {
    @Binding var journalText: String
    let onExit: () -> Void

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var noteMode: NoteEditorMode = .formatted

    private var palette: ThemePalette { themeManager.currentPalette }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Localizer.t("集中モード", "FOCUS", language: language))
                    .font(DS.smallCaption)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Spacer()
                Button {
                    noteMode = (noteMode == .formatted) ? .markdown : .formatted
                } label: {
                    // Reflects the mode you'd switch *to* — see
                    // ExtendedPageView's identical toggle.
                    Image(systemName: noteMode == .formatted ? "textformat" : "doc.richtext")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(noteMode == .formatted
                    ? Localizer.t("Markdownで編集", "Switch to Markdown", language: language)
                    : Localizer.t("整形されたテキストで表示", "Switch to formatted text", language: language))
                .accessibilityLabel(noteMode == .formatted
                    ? Localizer.t("Markdownで編集", "Switch to Markdown", language: language)
                    : Localizer.t("整形されたテキストで表示", "Switch to formatted text", language: language))

                Button(action: onExit) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut(.escape, modifiers: [])
                .help(Localizer.t("集中モードを終了", "Exit Focus Mode", language: language))
                .accessibilityLabel(Localizer.t("集中モードを終了", "Exit Focus Mode", language: language))
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 12)

            MarkdownRichNoteEditor(journalText: $journalText, mode: noteMode, themePalette: palette)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.paper)
        .foregroundStyle(DS.text)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
    }
}
