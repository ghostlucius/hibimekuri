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

    /// Shared between this view's compact and extended branches so
    /// `.matchedGeometryEffect` can recognize the task list, note box, and
    /// tear button as the *same* elements across the swap and animate
    /// their frame (position + size) from the compact position to the
    /// extended one, instead of just crossfading two unrelated view
    /// trees. This is the literal "tasks/notes swing to the right" the
    /// two-pane layout was designed around from the start but never
    /// actually animated until now.
    @Namespace private var transitionNamespace

    var body: some View {
        GeometryReader { geo in
            let isExtended = geo.size.width >= extendedThreshold
            Group {
                if isExtended {
                    ExtendedPageView(
                        entry: $entry,
                        quote: quote,
                        onTearOff: onTearOff,
                        onPrevDay: onPrevDay,
                        onNextDay: onNextDay,
                        onJumpToToday: onJumpToToday,
                        transitionNamespace: transitionNamespace
                    )
                    .transition(.opacity)
                } else {
                    compactBody
                        .transition(.opacity)
                }
            }
            // The header/numeral/almanac/calendar block isn't matched —
            // it's already nearly identical in both modes (same fixed-ish
            // width, same component, same position at the top of a
            // column), so it just fades in place. Tasks and the note box
            // are the two elements that genuinely relocate (single column
            // → dedicated right pane), so those are the ones tagged with
            // `.matchedGeometryEffect` below and in `ExtendedPageView`.
            // A longer duration than a plain crossfade needs, because a
            // flying/resizing element reads as motion — too fast and it
            // just looks like another snap.
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: isExtended)
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
                    .matchedGeometryEffect(id: "tasks", in: transitionNamespace)
                MemoBox(text: $entry.journalText)
                    .matchedGeometryEffect(id: "note", in: transitionNamespace)
                Spacer(minLength: 2)
                if let onTearOff {
                    tearButton(onTearOff)
                        .matchedGeometryEffect(id: "tearButton", in: transitionNamespace)
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
            .overlay(
                Rectangle().stroke(DS.text, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(Localizer.t("今日を完了として切り取ります", "Mark today complete and tear off the page", language: language))
    }
}
