import SwiftUI

/// Whether the distraction-free note editor (`FocusModeView`) is showing,
/// and which entry's note it's editing. A plain `@Observable` object
/// injected once at `RootView` rather than local `@State` deep in
/// `ExtendedPageView`. Focus Mode replaces the entire normal page, so the
/// toggle must be visible to both the note toolbars that enter it and the
/// root view that swaps the page out.
@Observable
final class FocusModeController {
    var isActive = false
    var journalText: Binding<String>?
    /// The page to reveal when Focus Mode closes. Keeping this outside
    /// `TodayView` lets the normal page unmount while its AppKit editor is
    /// replaced, without losing the user's place in the horizontal pager.
    var returnDate: Date?

    func enter(editing journalText: Binding<String>, from pageDate: Date? = nil) {
        self.journalText = journalText
        returnDate = pageDate
        isActive = true
    }

    func exit() {
        isActive = false
        journalText = nil
    }

    func clearReturnContext() {
        returnDate = nil
    }
}
