import SwiftUI

struct EditablePageView: View {
    @Binding var entry: DiaryEntry
    let quote: Quote?
    var onTearOff: (() -> Void)? = nil

    @AppStorage("appLanguage") private var language: AppLanguage = .japanese

    var body: some View {
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
            .frame(maxWidth: .infinity)
        }
        .background(DS.paper)
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
                Rectangle().stroke(Color.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(Localizer.t("今日を完了として切り取ります", "Mark today complete and tear off the page", language: language))
    }
}
