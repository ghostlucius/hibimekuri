import Foundation

enum AppScreen {
    case today
    case archive
}

/// Shared so any page (e.g. Archive, after restoring an entry) can switch
/// the app back to Today without threading a callback through every view.
@Observable
final class Navigator {
    var screen: AppScreen = .today
}
