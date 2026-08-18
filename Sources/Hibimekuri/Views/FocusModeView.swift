import AppKit
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
    @State private var escapeMonitor: Any?

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
        .onExitCommand(perform: onExit)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
        .onAppear(perform: installEscapeMonitor)
        .onDisappear(perform: removeEscapeMonitor)
    }

    /// Belt-and-suspenders alongside the exit button's own
    /// `.keyboardShortcut(.escape)` and the `.onExitCommand` above: with the
    /// note editor focused, an earlier build of this view had Escape do
    /// nothing at all. Same class of gap as
    /// `HibimekuriApp.installFocusResignOnOutsideClick()` (SwiftUI's own
    /// hit-testing/event handling not reliably reaching an AppKit-hosted
    /// first responder) — same fix shape: a local `NSEvent` monitor sees
    /// the key event before any responder does, so it doesn't depend on
    /// where first responder actually is.
    ///
    /// Must not swallow Escape unconditionally, though: the formatted
    /// editor's own link-entry field (`RichNoteEditor`'s `enteringLink`
    /// `TextField`) already uses Escape, via its own `.onExitCommand`, to
    /// cancel just the link entry — and that field can be focused while
    /// Focus Mode is open. `NSTextView.isFieldEditor` is what distinguishes
    /// the two: true only when a text view is standing in as a single
    /// field's editor (as it is for that `TextField`), false for the
    /// standalone document-editing text views this app hosts directly
    /// (`ChecklistTextView`, `PlainMarkdownEditor`'s view) — so checking it
    /// here lets the link field cancel itself first, and only exits Focus
    /// Mode once the real note editor (or nothing in particular) has focus.
    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53 else { return event } // 53 = Escape
            if let focusedEditor = NSApp.keyWindow?.firstResponder as? NSTextView, focusedEditor.isFieldEditor {
                return event
            }
            onExit()
            return nil // consumed — don't also hand it to the key view loop
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
        escapeMonitor = nil
    }
}
