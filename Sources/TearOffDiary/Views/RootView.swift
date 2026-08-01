import SwiftUI

struct RootView: View {
    @State private var navigator = Navigator()

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            cornerMenu
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(navigator)
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
