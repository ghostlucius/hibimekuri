import SwiftUI
import AppKit

struct TodayView: View {
    var catchUpRequestID = 0
    var focusReturnDate: Date?
    var onFocusPageRestored: () -> Void = {}

    @Environment(DiaryStore.self) private var store
    @Environment(QuoteStore.self) private var quoteStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese

    @State private var currentDate: Date = DiaryEntry.startOfDay(Date())
    @State private var revealDate: Date?
    @State private var isTearing = false
    @State private var scrollPositionID: Date?
    @State private var handledCatchUpRequestID = 0

    /// How far ahead of the current page you can scroll to peek/jot a note
    /// (three weeks is plenty for "remind me next week" without generating
    /// an unbounded page list).
    private let lookaheadDays = 21

    private var pageDates: [Date] {
        (0..<lookaheadDays).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: currentDate).map(DiaryEntry.startOfDay)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pageDates, id: \.self) { date in
                        pageCell(for: date)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            // .paging (not used here) snaps based on the scroll gesture's
            // own projected travel distance, which is a fraction of page
            // width — at the extended layout's much wider page (1000pt+
            // vs. compact's 390pt), the same trackpad swipe covers a much
            // smaller fraction of the page, so it took far more physical
            // scrolling to cross the threshold and could stall exactly
            // halfway. .viewAligned snaps to whichever page edge the
            // gesture ends closer to instead, so the decision doesn't
            // scale with page width the same way.
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $scrollPositionID)
            .scrollIndicators(.hidden)
        }
        .background(DS.paper.ignoresSafeArea())
        .task(id: catchUpRequestID) {
            setUpCurrentDate()
            restoreFocusPageIfNeeded()
            if catchUpRequestID != 0, handledCatchUpRequestID != catchUpRequestID {
                handledCatchUpRequestID = catchUpRequestID
                catchUpToToday()
            }
        }
        .onChange(of: currentDate) { _, newValue in
            scrollPositionID = newValue
        }
    }

    /// The current (frontmost) page keeps the original tear-off machinery
    /// exactly as before — including revealing the next page underneath
    /// immediately as it tears — so that behavior isn't disturbed by also
    /// being able to scroll further ahead. Pages beyond it are plain,
    /// memo-editable previews with no tear button.
    @ViewBuilder
    private func pageCell(for date: Date) -> some View {
        if Calendar.current.isDate(date, inSameDayAs: currentDate) {
            currentPageCell
        } else {
            EditablePageView(
                entry: binding(for: date),
                quote: quote(for: date),
                onPrevDay: prevDayAction(from: date),
                onNextDay: nextDayAction(from: date),
                onJumpToToday: jumpToTodayAction(from: date)
            )
        }
    }

    private var currentPageCell: some View {
        ZStack {
            if let revealDate, let revealEntry = store.entry(for: revealDate) {
                EditablePageView(
                    entry: binding(for: revealDate),
                    quote: quoteStore.quote(withId: revealEntry.quoteId)
                )
            }

            EditablePageView(
                entry: binding(for: currentDate),
                quote: quote(for: currentDate),
                onTearOff: performTearOff,
                onPrevDay: prevDayAction(from: currentDate),
                onNextDay: nextDayAction(from: currentDate),
                onJumpToToday: jumpToTodayAction(from: currentDate)
            )
            .rotation3DEffect(
                .degrees(!reduceMotion && isTearing ? -26 : 0),
                axis: (x: 0, y: 0, z: 1),
                anchor: .topLeading
            )
            .offset(x: !reduceMotion && isTearing ? -70 : 0, y: !reduceMotion && isTearing ? -560 : 0)
            .opacity(isTearing ? 0 : 1)
            .shadow(color: .black.opacity(!reduceMotion && isTearing ? 0.25 : 0), radius: 16, y: 10)
        }
    }

    /// Falls back to the deterministic per-day quote even for a future date
    /// that hasn't been persisted yet, so scrolled-ahead pages still show
    /// their quote card instead of a blank one until first edited.
    private func quote(for date: Date) -> Quote? {
        if let entry = store.entry(for: date) {
            return quoteStore.quote(withId: entry.quoteId)
        }
        return quoteStore.quote(for: date)
    }

    private func binding(for date: Date) -> Binding<DiaryEntry> {
        Binding(
            get: { store.entry(for: date) ?? DiaryEntry(date: date, quoteId: quoteStore.quote(for: date)?.id ?? "") },
            set: { store.upsert($0) }
        )
    }

    /// nil (disabling the control) when `date` is already the earliest page
    /// — matches the existing forward-only design: you can step back toward
    /// today through pages you've scrolled ahead into, never past it.
    private func prevDayAction(from date: Date) -> (() -> Void)? {
        guard let idx = pageDates.firstIndex(of: date), idx > 0 else { return nil }
        let target = pageDates[idx - 1]
        return { scrollPositionID = target }
    }

    private func nextDayAction(from date: Date) -> (() -> Void)? {
        guard let idx = pageDates.firstIndex(of: date), idx < pageDates.count - 1 else { return nil }
        let target = pageDates[idx + 1]
        return {
            store.ensureEntry(for: target, quoteStore: quoteStore)
            scrollPositionID = target
        }
    }

    private func jumpToTodayAction(from date: Date) -> (() -> Void)? {
        guard !Calendar.current.isDate(date, inSameDayAs: currentDate) else { return nil }
        return { scrollPositionID = currentDate }
    }

    private func setUpCurrentDate() {
        currentDate = store.currentDate()
        store.ensureEntry(for: currentDate, quoteStore: quoteStore)
        scrollPositionID = currentDate
    }

    /// `RootView` deliberately unmounts the normal page while Focus Mode is
    /// active so two native note editors never share one binding. Restore the
    /// pager position after that replacement so leaving Focus Mode returns to
    /// the page the user was writing on rather than always jumping to today.
    private func restoreFocusPageIfNeeded() {
        guard let focusReturnDate else { return }
        let target = DiaryEntry.startOfDay(focusReturnDate)
        guard target >= currentDate, pageDates.contains(target) else {
            onFocusPageRestored()
            return
        }
        store.ensureEntry(for: target, quoteStore: quoteStore)
        scrollPositionID = target
        onFocusPageRestored()
    }

    private func performTearOff() {
        SoundEffects.shared.playTearOff()
        tearOffCurrentPage(duration: 0.5)
    }

    /// Shared by the normal single-day tear and the rapid catch-up
    /// sequence below — they only differ in timing and whether they chain
    /// into another tear on completion. Doesn't play the sound itself;
    /// callers decide (the catch-up sequence plays it once for the whole
    /// run, not once per page).
    private func tearOffCurrentPage(duration: Double, completion: (() -> Void)? = nil) {
        guard var entry = store.entry(for: currentDate), !entry.isCompleted, !isTearing else { return }

        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate).map(DiaryEntry.startOfDay) ?? currentDate
        store.ensureEntry(for: nextDate, quoteStore: quoteStore)
        revealDate = nextDate

        let effectiveDuration = reduceMotion ? 0.01 : duration
        withAnimation(reduceMotion ? .linear(duration: effectiveDuration) : .easeIn(duration: effectiveDuration)) {
            isTearing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + effectiveDuration) {
            entry.isCompleted = true
            entry.completedAt = Date()
            store.upsert(entry)
            currentDate = nextDate
            revealDate = nil
            isTearing = false
            completion?()
        }
    }

    /// Rapidly tears through every backlog day between the current
    /// frontier (see `DiaryStore.currentDate()`'s doc comment for why
    /// that can drift behind the real calendar date) and today, landing
    /// on today as the new, editable current page. Each page gets a much
    /// shorter animation than a normal tear so catching up several days
    /// doesn't take several seconds, and the tear sound plays once for
    /// the whole run rather than once per page.
    private func catchUpToToday() {
        guard !isTearing else { return }
        let realToday = DiaryEntry.startOfDay(Date())
        guard currentDate < realToday else { return }
        SoundEffects.shared.playTearOff()
        tearCatchUpPage(until: realToday)
    }

    private func tearCatchUpPage(until realToday: Date) {
        guard currentDate < realToday else {
            announceCatchUpComplete()
            return
        }
        tearOffCurrentPage(duration: 0.18) {
            tearCatchUpPage(until: realToday)
        }
    }

    private func announceCatchUpComplete() {
        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: Localizer.t("今日まで追いつきました。", "Caught up to today.", language: language)]
        )
    }
}
