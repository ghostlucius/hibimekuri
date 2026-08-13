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

    // Was `@Namespace` + `.matchedGeometryEffect` on the task list, note
    // box, and tear button, so they'd visually fly/resize from their
    // compact position to their extended one instead of crossfading — a
    // literal geometry morph. Removed in favor of a plain opacity crossfade
    // — confirmed directly, more than once, that a crossfade (not a morph)
    // is what was actually wanted.
    //
    // That crossfade was originally implemented as `if isExtended {
    // ExtendedPageView() } else { compactBody }` inside a `Group`, with
    // `.transition(.opacity)` on each branch — the standard SwiftUI recipe
    // for animating a conditional swap. In practice this did not read as a
    // fade: content appeared/disappeared abruptly instead. Two compounding
    // problems, not one:
    //
    // 1. `.transition()` only animates reliably when the state change that
    //    triggers the insertion/removal happens inside an animation
    //    transaction. `.animation(_:value:)` is supposed to provide that
    //    for the whole subtree, but for a *structural* if/else swap (not
    //    just a property change) it's the less robust of the two supported
    //    patterns — `withAnimation` around the actual mutation is the
    //    reliable one, so every place that sets `isExtended` below wraps it
    //    explicitly instead of leaning on an ambient `.animation()` modifier.
    // 2. Each branch was a *fresh* view every time it appeared — a new
    //    `ExtendedPageView`, a new `DiaryIllustrationView` inside it, reset
    //    `@State`, from zero. Even with the transition firing correctly,
    //    the illustration specifically still had nothing to show for the
    //    first several frames while its image loaded, i.e. still popped in
    //    rather than fading in the exact motion it should have.
    //
    // Fixed by not mounting/unmounting either side at all: both
    // `compactBody` and `ExtendedPageView` are always present, stacked, and
    // cross-faded via plain `.opacity()` — an ordinary property animation,
    // not a transition on a structural change, which is the more reliable
    // of the two in SwiftUI. This is also exactly what keeps the
    // illustration persistent instead of reloading: `ExtendedPageView`
    // (and the `DiaryIllustrationView` inside it) is created once, the
    // moment this page itself appears, regardless of which mode the window
    // starts in — so its image has the entire time before a user ever
    // drags the window wide to finish loading in the background, matching
    // `IllustrationLoader`'s launch-time warm-up.
    @State private var isExtended = false

    private var transitionAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.65)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ZStack sizes itself to its *largest* child by default —
                // both children are always present now (that's the whole
                // point, see above), and ExtendedPageView's fixed 400pt
                // left pane plus flexible right pane wants far more than
                // 390pt. Without pinning each child to the real current
                // size explicitly, that demand leaked into the container
                // even while ExtendedPageView sat at opacity 0: the
                // compact page's own right-aligned content (month name,
                // mini calendars, the jūnichoku column) got laid out
                // against that wider phantom width and ran off the actual
                // window's right edge — confirmed via screenshot, not a
                // theoretical worry. Each child gets the outer
                // GeometryReader's actual size directly, so neither one's
                // natural width can influence the other or the container.
                compactBody
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(isExtended ? 0 : 1)
                    .allowsHitTesting(!isExtended)
                ExtendedPageView(
                    entry: $entry,
                    quote: quote,
                    onTearOff: onTearOff,
                    onPrevDay: onPrevDay,
                    onNextDay: onNextDay,
                    onJumpToToday: onJumpToToday
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .opacity(isExtended ? 1 : 0)
                .allowsHitTesting(isExtended)
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
