import SwiftUI
import AppKit

/// The one true window size — used both for the initial `.defaultSize` and
/// to force it on every launch (see `AppDelegate`, below). Compact width
/// matches an iPhone screen (390pt ≈ iPhone 15/16) rather than a document
/// window — the whole point of the compact layout is to read as a small
/// physical desk calendar, not a Mac-sized app window.
enum WindowMetrics {
    static let defaultSize = NSSize(width: 390, height: 700)
}

/// `swift run` launches this without a proper .app bundle, so AppKit never
/// activates it as the foreground app on its own — keystrokes keep going to
/// whatever window (e.g. the launching terminal) actually held key status.
/// Forcing activation here is what makes the window actually receive focus.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearanceController.applyStoredPreference()
        AppIconManager.applyForCurrentSystemAppearance()
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
        if let window = NSApp.windows.first {
            // isRestorable=false above stops AppKit's state-restoration
            // snapshot, but SwiftUI's WindowGroup *separately* autosaves the
            // frame to UserDefaults under a key derived from the view
            // hierarchy's generic type signature (confirmed via `defaults
            // read` — several stale "NSWindow Frame ..." entries pile up
            // there, one per code revision, since that signature changes
            // whenever the modifier chain does). Any manual resize during a
            // session sticks in that key and silently overrides
            // `.defaultSize` on next launch. Forcing the content size here,
            // every launch, makes the visible behavior match what
            // `.defaultSize` implies rather than depending on that hidden
            // per-build cache.
            window.setContentSize(WindowMetrics.defaultSize)
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
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system

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
                // No max width/height anymore: past a width threshold,
                // EditablePageView switches to the redesigned two-pane
                // extended layout (see ExtendedPageView) instead of
                // stretching the compact page, so there's no ceiling to
                // enforce — both the compact iPhone-width layout and the
                // wide extended layout are meant to fill whatever space
                // they're actually given.
                .frame(minWidth: 375, minHeight: 600)
                .onChange(of: appearance, initial: true) { _, newValue in
                    AppearanceController.apply(newValue)
                }
        }
        .defaultSize(width: WindowMetrics.defaultSize.width, height: WindowMetrics.defaultSize.height)

        Settings {
            SettingsView()
                .environment(diaryStore)
                .environment(quoteStore)
                .environment(taskStore)
        }
    }
}
