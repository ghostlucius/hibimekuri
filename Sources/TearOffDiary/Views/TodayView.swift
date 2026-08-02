import SwiftUI

struct TodayView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(QuoteStore.self) private var quoteStore

    @State private var currentDate: Date = DiaryEntry.startOfDay(Date())
    @State private var revealDate: Date?
    @State private var isTearing = false
    @State private var scrollPositionID: Date?

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
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPositionID)
            .scrollIndicators(.hidden)
        }
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .task { setUpCurrentDate() }
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
                .degrees(isTearing ? -26 : 0),
                axis: (x: 0, y: 0, z: 1),
                anchor: .topLeading
            )
            .offset(x: isTearing ? -70 : 0, y: isTearing ? -560 : 0)
            .opacity(isTearing ? 0 : 1)
            .shadow(color: .black.opacity(isTearing ? 0.25 : 0), radius: 16, y: 10)
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

    private func performTearOff() {
        guard var entry = store.entry(for: currentDate), !entry.isCompleted, !isTearing else { return }

        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate).map(DiaryEntry.startOfDay) ?? currentDate
        store.ensureEntry(for: nextDate, quoteStore: quoteStore)
        revealDate = nextDate

        SoundEffects.shared.playTearOff()

        withAnimation(.easeIn(duration: 0.5)) {
            isTearing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            entry.isCompleted = true
            entry.completedAt = Date()
            store.upsert(entry)
            currentDate = nextDate
            revealDate = nil
            isTearing = false
        }
    }
}
