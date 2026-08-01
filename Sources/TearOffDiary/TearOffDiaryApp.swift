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
                // The page content caps at 560pt wide (see EditablePageView);
                // keep the window close to that so there's no dead gutter on
                // either side, while still leaving a little slack to resize.
                .frame(minWidth: 560, maxWidth: 620, minHeight: 640, maxHeight: 1100)
        }
        .defaultSize(width: 580, height: 820)

        Settings {
            SettingsView()
                .environment(diaryStore)
                .environment(quoteStore)
                .environment(taskStore)
        }
    }
}
