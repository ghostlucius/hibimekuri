import SwiftUI

struct EditablePageView: View {
    @Binding var entry: DiaryEntry
    let quote: Quote?
    var onTearOff: (() -> Void)? = nil
    var onPrevDay: (() -> Void)? = nil
    var onNextDay: (() -> Void)? = nil
    var onJumpToToday: (() -> Void)? = nil

    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Below this width: the compact single-column page (an iPhone-width
    /// "physical desk calendar" card). At or above it: the redesigned
    /// two-pane extended layout — a real alternate layout, not the compact
    /// page just centered on more background (that was tried and rejected).
    /// Shared with `AppDelegate`'s window-resize snapping via
    /// `WindowMetrics` — both must agree on the same number, or the window
    /// itself and the content it's showing can end up disagreeing about
    /// which mode should be active.
    private let extendedThreshold = WindowMetrics.extendedThreshold

    /// The compact page's actual design width — see
    /// `WindowMetrics.compactMaxWidth`, which the window itself is also
    /// capped at. `compactBody` caps itself here instead of stretching to
    /// fill whatever width the window has, so the compact page is pixel-
    /// identical at 390pt and at 800pt: only the empty margin around it
    /// grows, nothing inside it moves.
    private let compactDesignWidth = WindowMetrics.compactMaxWidth

    // Only the active layout is mounted. Keeping compact and extended pages
    // alive together creates two AppKit memo editors bound to the same text;
    // the hidden editor can then replace its text storage during a live edit.
    // The illustration is warmed at launch, so mounting the extended layout
    // at the transition boundary still has a ready bitmap to fade in.
    @State private var isExtended = false

    private var transitionAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.65)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isExtended {
                    ExtendedPageView(
                        entry: $entry,
                        quote: quote,
                        onTearOff: onTearOff,
                        onPrevDay: onPrevDay,
                        onNextDay: onNextDay,
                        onJumpToToday: onJumpToToday
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.opacity)
                } else {
                    compactBody
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(.opacity)
                }
            }
            // The default, organic path: a live drag that crosses the
            // threshold directly (past the dead zone AppDelegate snaps,
            // not into it) updates isExtended the moment the width
            // actually crosses. initial:true seeds the correct mode on
            // first layout without needing a resize first — not animated,
            // since this is the page's very first layout pass, not a
            // transition the user should see.
            .onChange(of: geo.size.width, initial: true) { _, width in
                let extended = width >= extendedThreshold
                guard extended != isExtended else { return }
                withAnimation(transitionAnimation) {
                    isExtended = extended
                }
            }
        }
        // The dead-zone snap path: AppDelegate posts this the instant it
        // decides which side to animate the window toward, before that
        // animation starts — so this flip (and the crossfade it triggers)
        // begins at the same moment the window starts resizing, not once
        // GeometryReader's width finally reaches the target. See
        // .layoutModeWillSnap's doc comment for the full reasoning; this is
        // what actually removes the pause.
        .onReceive(NotificationCenter.default.publisher(for: .layoutModeWillSnap)) { note in
            guard let extended = note.userInfo?["isExtended"] as? Bool, extended != isExtended else { return }
            withAnimation(transitionAnimation) {
                isExtended = extended
            }
        }
    }

    private var compactBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                DayPageHeader(date: entry.date, language: language)
                HairlineDivider()
                DailyQuoteView(date: entry.date, quote: quote)
                HairlineDivider()
                TaskListView()
                MemoBox(text: $entry.journalText)
                Spacer(minLength: 2)
                if let onTearOff {
                    tearButton(onTearOff)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            // Extra top clearance: the corner icon cluster (Today/Archive)
            // floats at a fixed position over the window, independent of
            // scroll position — without this the header's top-right month
            // text collides with it now that the page has gotten compact.
            .padding(.top, 44)
            // Capped at the design width, not stretched to fill it —
            // `.frame(maxWidth: .infinity)` here used to let the header's
            // date/month row and the numeral's side columns spread apart
            // as the window widened from 390pt up toward the extended
            // threshold, which is real visible movement of the compact
            // page for several hundred pixels of resize even though its
            // actual design never changes. `maxWidth` (not a fixed
            // `width`) still lets it shrink gracefully on the rare
            // narrower-than-390 window instead of clipping.
            .frame(maxWidth: compactDesignWidth)
            .frame(maxWidth: .infinity)
        }
        .background(DS.paper)
        .foregroundStyle(DS.text)
    }

    private func tearButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(Localizer.t("今日を切り取る", "TEAR OFF TODAY", language: language))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                Spacer()
            }
            .padding(.vertical, 8)
            // See OnboardingView's identical fix: Spacers paint nothing, so
            // without this only the Text label was actually clickable, not
            // the full button width.
            .contentShape(Rectangle())
            .overlay(
                Rectangle().stroke(DS.text, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(Localizer.t("今日を完了として切り取ります", "Mark today complete and tear off the page", language: language))
    }
}
