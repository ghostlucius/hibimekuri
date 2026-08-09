import SwiftUI
import AppKit

/// The one true window size — used both for the initial `.defaultSize` and
/// to force it on every launch (see `AppDelegate`, below). Compact width
/// matches an iPhone screen (390pt ≈ iPhone 15/16) rather than a document
/// window — the whole point of the compact layout is to read as a small
/// physical desk calendar, not a Mac-sized app window.
enum WindowMetrics {
    static let defaultSize = NSSize(width: 390, height: 700)

    /// The window itself is capped at this width while the compact layout
    /// is showing — matches `EditablePageView.compactDesignWidth` exactly,
    /// so the compact page never has empty margin floating around it and
    /// the window can never sit in the dead zone between "as wide as
    /// compact needs" and "wide enough for the extended layout." A single
    /// shared constant (not a private one duplicated in each file) because
    /// the resize-snapping logic in `AppDelegate` and the layout switch in
    /// `EditablePageView` both have to agree on the exact same numbers or
    /// the window and the content it's showing can disagree about which
    /// mode should be active.
    static let compactMaxWidth: CGFloat = 390

    /// Below this width: compact. At or above it: the two-pane extended
    /// layout. See `EditablePageView`.
    static let extendedThreshold: CGFloat = 820
}

/// Posted on every mouse-down, before SwiftUI's own gesture recognition
/// runs (see `installFocusResignOnOutsideClick`) — task rows use this to
/// clear their selected/open state on a click anywhere else, the same way
/// Things does. Firing unconditionally on every click and then letting
/// whichever row actually got tapped re-select/re-open itself immediately
/// after is simpler and more reliable than trying to hit-test "was this
/// click outside a specific row" from the AppKit layer.
extension Notification.Name {
    static let taskInteractionReset = Notification.Name("taskInteractionReset")
}

/// `swift run` launches this without a proper .app bundle, so AppKit never
/// activates it as the foreground app on its own — keystrokes keep going to
/// whatever window (e.g. the launching terminal) actually held key status.
/// Forcing activation here is what makes the window actually receive focus.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearanceController.applyStoredPreference()
        AppIconManager.start()
        installFocusResignOnOutsideClick()
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
            window.delegate = self
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

    /// Clicking outside a focused text field is supposed to resign it (that's
    /// how the memo/task-notes fields know to swap back to their rendered
    /// markdown preview) — but on macOS, unlike iOS/web, that's not
    /// automatic. A SwiftUI `.background` tap catcher was tried first and
    /// only worked over buttons/fields (which resign focus themselves); over
    /// blank ScrollView content it never fired, because NSScrollView claims
    /// its whole bounds for its own gesture handling and the tap never
    /// reaches a view sitting behind it in z-order. A local event monitor
    /// sidesteps SwiftUI's view hit-testing entirely — it sees every
    /// mouse-down before any view does, checks whether it landed inside the
    /// window's actual focused text view (the real source of truth, not
    /// SwiftUI's hit-testing), and resigns it if not.
    private func installFocusResignOnOutsideClick() {
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if let window = event.window, let textView = window.firstResponder as? NSTextView {
                let point = textView.convert(event.locationInWindow, from: nil)
                if !textView.bounds.contains(point) {
                    window.makeFirstResponder(nil)
                }
            }
            NotificationCenter.default.post(name: .taskInteractionReset, object: nil)
            return event
        }
    }

    /// After a live window resize ends, snap the window out of the "dead
    /// zone" between `WindowMetrics.compactMaxWidth` and `.extendedThreshold`.
    /// Below `compactMaxWidth` the compact page fills the window exactly,
    /// no margin; at or above `extendedThreshold` the two-pane extended
    /// layout takes over. Anything the user drags to in between shows the
    /// fixed-width compact page floating in empty space — the window
    /// itself was still freely resizable there even after the compact
    /// page stopped stretching to fill it, which just moved the "empty
    /// space" problem from inside the page to around it.
    ///
    /// This only fires once the drag has *ended*, not during it — snapping
    /// mid-drag would fight the user's mouse (the frame jumping away from
    /// the cursor while they're still holding the edge) and feel broken.
    /// Letting the drag complete and then gliding the window itself to
    /// whichever edge of the dead zone is closer is the same idea as the
    /// content crossfade in `EditablePageView`, extended to the window's
    /// own size: an actual animated transition instead of an instant snap.
    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let width = window.frame.width
        let compactMax = WindowMetrics.compactMaxWidth
        let extendedMin = WindowMetrics.extendedThreshold
        guard width > compactMax, width < extendedMin else { return }

        let distanceToCompact = width - compactMax
        let distanceToExtended = extendedMin - width
        let targetWidth = distanceToCompact < distanceToExtended ? compactMax : extendedMin

        var newFrame = window.frame
        newFrame.size.width = targetWidth
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true)
        }
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
                // No SwiftUI-level maxWidth here — that would be a single
                // static number, but the ceiling that actually makes sense
                // is conditional: capped at WindowMetrics.compactMaxWidth
                // while compact (the compact page is fixed-width now, see
                // EditablePageView — it never stretches), uncapped once
                // extended. AppDelegate.windowDidEndLiveResize enforces
                // that dynamic version directly on the NSWindow instead.
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
