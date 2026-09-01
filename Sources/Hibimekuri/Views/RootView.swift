import SwiftUI

struct RootView: View {
    @State private var navigator = Navigator()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var themeManager
    @Environment(DiaryStore.self) private var diaryStore
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var catchUpRequestID = 0
    @State private var focusMode = FocusModeController()
    @State private var taskInteraction = TaskInteractionController()

    /// The app's current page (see `DiaryStore.currentDate()`'s doc
    /// comment) can drift behind the real calendar date if days go by
    /// without the user tearing one off. The catch-up icon only appears
    /// when that's actually true, so the corner cluster stays exactly as
    /// minimal as before the rest of the time.
    private var isBehindRealToday: Bool {
        diaryStore.currentDate() < DiaryEntry.startOfDay(Date())
    }

    var body: some View {
        Group {
            if focusMode.isActive, let journalText = focusMode.journalText {
                FocusModeView(journalText: journalText, onExit: focusMode.exit)
            } else {
                Group {
                    switch navigator.screen {
                    case .today:
                        TodayView(
                            catchUpRequestID: catchUpRequestID,
                            focusReturnDate: focusMode.returnDate,
                            onFocusPageRestored: focusMode.clearReturnContext
                        )
                    case .archive:
                        NavigationStack {
                            ArchiveView()
                        }
                    }
                }
                .overlay(alignment: .topTrailing) { cornerMenu }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(navigator)
        .environment(focusMode)
        .environment(taskInteraction)
        // Tracks both an explicit Light/Dark choice and, while "System" is
        // selected, live system appearance changes — colorScheme reflects
        // NSApp's effective appearance either way. ThemeManager relies on
        // this same signal (see its own doc comment) rather than detecting
        // system appearance a second, independent way.
        .onChange(of: colorScheme, initial: true) { _, newValue in
            AppIconManager.apply(colorScheme: newValue)
            themeManager.systemColorScheme = newValue
        }
        .sheet(isPresented: onboardingBinding) {
            OnboardingView {
                hasSeenOnboarding = true
            }
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { isPresented in
                if !isPresented {
                    hasSeenOnboarding = true
                }
            }
        )
    }

    private var cornerMenu: some View {
        HStack(spacing: 14) {
            // Only present when the app's page has actually drifted behind
            // the real date — absent the rest of the time, so this doesn't
            // permanently add a third icon to what's meant to stay a
            // minimal two-icon cluster.
            if isBehindRealToday {
                cornerButton(
                    "chevron.forward.2",
                    label: Localizer.t("今日まで追いつく", "Catch up to today", language: language),
                    isActive: false
                ) {
                    navigator.screen = .today
                    catchUpRequestID += 1
                }
                .transition(.opacity)
            }
            cornerButton("sun.max", label: Localizer.t("今日", "Today", language: language), isActive: navigator.screen == .today) { navigator.screen = .today }
            cornerButton("square.stack", label: Localizer.t("アーカイブ", "Archive", language: language), isActive: navigator.screen == .archive) { navigator.screen = .archive }
        }
        .padding(14)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isBehindRealToday)
    }

    private func cornerButton(_ systemName: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? DS.text : DS.textSecondary.opacity(0.7))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
