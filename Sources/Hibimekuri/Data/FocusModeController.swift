import SwiftUI

/// Whether the distraction-free note editor (`FocusModeView`) is showing,
/// and which entry's note it's editing. A plain `@Observable` object
/// injected once at `RootView` rather than local `@State` deep in
/// `ExtendedPageView` — Focus Mode has to cover the *entire* window,
/// including the corner Today/Archive icon cluster `RootView` overlays on
/// top of everything else, so the toggle has to be visible from both ends:
/// `ExtendedPageView`'s note toolbar sets it, `RootView`'s own overlay
/// reads it.
@Observable
final class FocusModeController {
    var isActive = false
    var journalText: Binding<String>?

    func enter(editing journalText: Binding<String>) {
        self.journalText = journalText
        isActive = true
    }

    func exit() {
        isActive = false
    }
}
