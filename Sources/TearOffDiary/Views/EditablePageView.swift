import SwiftUI

struct EditablePageView: View {
    @Binding var entry: DiaryEntry
    let quote: Quote?
    var onTearOff: (() -> Void)? = nil

    @AppStorage("appLanguage") private var language: AppLanguage = .japanese

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DayPageHeader(date: entry.date, language: language)
                HairlineDivider()
                DailyQuoteView(date: entry.date, quote: quote)
                HairlineDivider()
                TaskListView()
                MemoBox(text: $entry.journalText)
                Spacer(minLength: 4)
                if let onTearOff {
                    tearButton(onTearOff)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .background(DS.paper)
    }

    private func tearButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(Localizer.t("今日を切り取る", "TEAR OFF TODAY", language: language))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
                Spacer()
            }
            .padding(.vertical, 10)
            .overlay(
                Rectangle().stroke(Color.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(Localizer.t("今日を完了として切り取ります", "Mark today complete and tear off the page", language: language))
    }
}
