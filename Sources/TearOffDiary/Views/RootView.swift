import SwiftUI

struct RootView: View {
    @State private var navigator = Navigator()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch navigator.screen {
            case .today:
                TodayView()
            case .archive:
                NavigationStack {
                    ArchiveView()
                }
            }
        }
        // Force this to fill the window BEFORE attaching the overlay, so the
        // icon cluster is positioned relative to the real window bounds —
        // not to whatever small size the active screen's content wants.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Back to the raw top-trailing corner: the earlier cap-and-center
        // wrapper existed only for when fullscreen showed the compact page
        // centered on extra background. That approach was replaced by
        // ExtendedPageView's own two-pane layout, which already extends to
        // the window's real right edge, so the plain corner overlay lines
        // up correctly in both compact and extended mode again.
        .overlay(alignment: .topTrailing) { cornerMenu }
        .environment(navigator)
        // Tracks both an explicit Light/Dark choice and, while "System" is
        // selected, live system appearance changes — colorScheme reflects
        // NSApp's effective appearance either way.
        .onChange(of: colorScheme, initial: true) { _, newValue in
            AppIconManager.apply(colorScheme: newValue)
        }
    }

    private var cornerMenu: some View {
        HStack(spacing: 14) {
            cornerButton("sun.max", isActive: navigator.screen == .today) { navigator.screen = .today }
            cornerButton("square.stack", isActive: navigator.screen == .archive) { navigator.screen = .archive }
        }
        .padding(14)
    }

    private func cornerButton(_ systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.primary : Color.secondary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}
