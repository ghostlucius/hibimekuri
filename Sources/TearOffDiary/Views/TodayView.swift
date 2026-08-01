import SwiftUI

struct TodayView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(QuoteStore.self) private var quoteStore

    @State private var currentDate: Date = DiaryEntry.startOfDay(Date())
    @State private var revealDate: Date?
    @State private var isTearing = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            // The next page, revealed underneath as the current one tears away.
            if let revealDate, let revealEntry = store.entry(for: revealDate) {
                EditablePageView(
                    entry: binding(for: revealDate),
                    quote: quoteStore.quote(withId: revealEntry.quoteId)
                )
            }

            if let entry = store.entry(for: currentDate) {
                EditablePageView(
                    entry: binding(for: currentDate),
                    quote: quoteStore.quote(withId: entry.quoteId),
                    onTearOff: performTearOff
                )
                .rotation3DEffect(
                    .degrees(isTearing ? -26 : 0),
                    axis: (x: 0, y: 0, z: 1),
                    anchor: .topLeading
                )
                .offset(x: isTearing ? -70 : 0, y: isTearing ? -560 : 0)
                .opacity(isTearing ? 0 : 1)
                .shadow(color: .black.opacity(isTearing ? 0.25 : 0), radius: 16, y: 10)
            } else {
                ProgressView()
            }
        }
        .task { setUpCurrentDate() }
    }

    private func binding(for date: Date) -> Binding<DiaryEntry> {
        Binding(
            get: { store.entry(for: date) ?? DiaryEntry(date: date, quoteId: "") },
            set: { store.upsert($0) }
        )
    }

    private func setUpCurrentDate() {
        currentDate = store.currentDate()
        store.ensureEntry(for: currentDate, quoteStore: quoteStore)
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
