import SwiftUI

struct ArchiveView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(QuoteStore.self) private var quoteStore
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @State private var searchText = ""

    private var pastEntries: [DiaryEntry] {
        store.entries
            .filter { $0.isCompleted }
            .sorted { $0.date > $1.date }
    }

    private var filteredEntries: [DiaryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return pastEntries }
        return pastEntries.filter { entry in
            let dateLabel = CalendarDay(date: entry.date).fullDateLabel(language: language)
            return entry.journalText.localizedCaseInsensitiveContains(query)
                || dateLabel.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if pastEntries.isEmpty {
                ContentUnavailableView(
                    Localizer.t("まだ記録がありません", "No entries yet", language: language),
                    systemImage: "square.stack",
                    description: Text(Localizer.t("切り取ったページがここに表示されます。", "Torn-off pages will appear here.", language: language))
                )
            } else if filteredEntries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredEntries) { entry in
                    NavigationLink {
                        ArchiveDetailView(entry: entry, quote: quoteStore.quote(withId: entry.quoteId))
                    } label: {
                        ArchiveRow(entry: entry, language: language)
                    }
                }
                .listStyle(.inset)
            }
        }
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: Localizer.t("記録または日付を検索", "Search entries or dates", language: language)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(DS.text)
        .navigationTitle(Localizer.t("アーカイブ", "Archive", language: language))
    }
}

private struct ArchiveRow: View {
    let entry: DiaryEntry
    let language: AppLanguage
    private var day: CalendarDay { CalendarDay(date: entry.date) }

    var body: some View {
        HStack(spacing: 14) {
            VStack {
                Text(day.dayNumber)
                    .font(.system(size: 22, weight: .black))
                Text(day.weekdayLabel(language: .english).prefix(3).uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.fullDateLabel(language: language))
                    .font(.system(size: 12, weight: .medium))
                Text(entry.journalText.isEmpty ? Localizer.t("記録なし", "No entry", language: language) : entry.journalText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}
