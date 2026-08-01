import SwiftUI
import AppKit

/// `swift run` launches this without a proper .app bundle, so AppKit never
/// activates it as the foreground app on its own — keystrokes keep going to
/// whatever window (e.g. the launching terminal) actually held key status.
/// Forcing activation here is what makes the window actually receive focus.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            // Every dev rebuild reuses the same bundle identifier, so macOS's
            // window-frame restoration was reopening the window at whatever
            // size the *very first* test launch used, ignoring any later
            // frame/size changes in code. Opting this window out of that
            // system entirely is what makes .frame()/.defaultSize() in
            // TearOffDiaryApp actually the source of truth going forward.
            window.isRestorable = false
        }
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}

@main
struct TearOffDiaryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let quoteStore = QuoteStore()
    let diaryStore = DiaryStore()
    let taskStore = TaskStore()
    let wordStore = WordStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(quoteStore)
                .environment(diaryStore)
                .environment(taskStore)
                .environment(wordStore)
                // Page content fills whatever width it's given (see
                // EditablePageView) rather than capping at a fixed value, so
                // there's no dead gutter regardless of where the window ends
                // up in this range.
                .frame(minWidth: 560, maxWidth: 800, minHeight: 640, maxHeight: 1100)
        }
        .defaultSize(width: 620, height: 820)

        Settings {
            SettingsView()
                .environment(diaryStore)
                .environment(quoteStore)
                .environment(taskStore)
        }
    }
}
