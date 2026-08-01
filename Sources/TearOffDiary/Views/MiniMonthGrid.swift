import SwiftUI

/// Small reference calendar for one month, like the tiny prev/next month
/// grids printed in the corners of a himekuri page.
struct MiniMonthGrid: View {
    let monthDate: Date
    var highlight: Date? = nil
    var language: AppLanguage = .japanese

    private let calendar = Calendar.current

    private var cells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthDate) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        var result: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for offset in 0..<daysInMonth {
            result.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(Localizer.month(number: calendar.component(.month, from: monthDate), language: language))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 2) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Localizer.miniWeekday(index: i, language: language))
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(cells.indices, id: \.self) { idx in
                    if let d = cells[idx] {
                        let isHighlighted = highlight.map { calendar.isDate($0, inSameDayAs: d) } ?? false
                        Text(verbatim: "\(calendar.component(.day, from: d))")
                            .font(.system(size: 7))
                            .frame(maxWidth: .infinity, minHeight: 12)
                            .foregroundStyle(isHighlighted ? DS.paper : .secondary)
                            .background(
                                Circle().fill(isHighlighted ? Color.primary : Color.clear)
                            )
                    } else {
                        Text("")
                            .font(.system(size: 7))
                            .frame(maxWidth: .infinity, minHeight: 12)
                    }
                }
            }
        }
        .frame(width: 100)
    }
}
