import SwiftUI

struct ArchiveDetailView: View {
    let entry: DiaryEntry
    let quote: Quote?

    @Environment(DiaryStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese

    private var day: CalendarDay { CalendarDay(date: entry.date) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DayPageHeader(date: entry.date, language: language)

                HairlineDivider()

                DailyQuoteView(date: entry.date, quote: quote)

                HairlineDivider()

                MemoBox(text: .constant(entry.journalText), isEditable: false)

                HStack {
                    if entry.isCompleted, let completedAt = entry.completedAt {
                        Text(Localizer.t("切り取り時刻 \(completedAt.formatted(date: .omitted, time: .shortened))", "Torn off \(completedAt.formatted(date: .omitted, time: .shortened))", language: language))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button(Localizer.t("このページを復元", "Restore this page", language: language)) {
                        restore()
                    }
                    .font(.system(size: 12))
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(day.fullDateLabel(language: language))
    }

    private func restore() {
        var restored = entry
        restored.isCompleted = false
        restored.completedAt = nil
        store.upsert(restored)
        navigator.screen = .today
    }
}
