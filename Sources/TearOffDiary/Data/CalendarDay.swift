import Foundation

/// Precomputed display strings for one calendar day, in the tear-off
/// calendar's himekuri style (big numeral, kanji weekday, era year).
/// Raw Japanese values here are the canonical data; Localizer decides
/// how to display them per the app's language setting.
struct CalendarDay {
    let date: Date

    private static let englishFullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    private static let japaneseFullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月 d日"
        return formatter
    }()

    var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    var monthNumber: Int {
        Calendar.current.component(.month, from: date)
    }

    var year: Int {
        Calendar.current.component(.year, from: date)
    }

    var weekdayIndex: Int {
        Calendar.current.component(.weekday, from: date) - 1
    }

    func weekdayLabel(language: AppLanguage) -> String {
        Localizer.weekday(index: weekdayIndex, language: language)
    }

    func monthLabel(language: AppLanguage) -> String {
        Localizer.month(number: monthNumber, language: language)
    }

    /// Reiwa era began 2019-05-01; Reiwa 1 == 2019. Close enough for a
    /// decorative label without pulling in the era-aware calendar APIs.
    var eraLabel: String {
        let reiwaYear = year - 2018
        return "令和\(reiwaYear)年"
    }

    /// Reference-only continuation counts for the two prior eras, the way
    /// printed calendars caption them for readers who still think in those years.
    var priorEraLabels: [String] {
        var labels: [String] = []
        let heisei = year - 1988
        if heisei >= 1 { labels.append("平成\(heisei)年") }
        let showa = year - 1925
        if showa >= 1 { labels.append("昭和\(showa)年") }
        return labels
    }

    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    func fullDateLabel(language: AppLanguage) -> String {
        if language == .english {
            return Self.englishFullDateFormatter.string(from: date)
        }
        return Self.japaneseFullDateFormatter.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}
