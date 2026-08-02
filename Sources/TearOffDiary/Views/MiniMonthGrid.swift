import SwiftUI

/// Small reference calendar for one month, like the tiny prev/next month
/// grids printed in the corners of a himekuri page. Also reused, via
/// `large`, as the full-size grid the numeral flips into (see
/// `DayPageHeader`).
struct MiniMonthGrid: View {
    let monthDate: Date
    var highlight: Date? = nil
    /// Days that carry a task due date — rendered as a small dot.
    var markedDates: Set<Date> = []
    var language: AppLanguage = .japanese
    var large: Bool = false

    private let calendar = Calendar.current

    private var headerFont: CGFloat { large ? 11 : 8 }
    private var weekdayFont: CGFloat { large ? 8 : 6 }
    private var dayFont: CGFloat { large ? 9 : 6 }
    private var cellMinHeight: CGFloat { large ? 17 : 12 }
    private var dotSize: CGFloat { large ? 3.5 : 3 }
    private var gridWidth: CGFloat { large ? 168 : 92 }

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

    private func isMarked(_ d: Date) -> Bool {
        markedDates.contains(calendar.startOfDay(for: d))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Localizer.month(number: calendar.component(.month, from: monthDate), language: language))
                .font(.system(size: headerFont, weight: .bold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Localizer.miniWeekday(index: i, language: language))
                        .font(.system(size: weekdayFont))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(cells.indices, id: \.self) { idx in
                    if let d = cells[idx] {
                        let isHighlighted = highlight.map { calendar.isDate($0, inSameDayAs: d) } ?? false
                        Text(verbatim: "\(calendar.component(.day, from: d))")
                            .font(.system(size: dayFont))
                            .frame(maxWidth: .infinity, minHeight: cellMinHeight)
                            .foregroundStyle(isHighlighted ? DS.paper : .secondary)
                            .background(
                                Circle().fill(isHighlighted ? Color.primary : Color.clear)
                            )
                            .overlay(alignment: .bottom) {
                                if isMarked(d) {
                                    Circle()
                                        .fill(isHighlighted ? DS.paper : Color.primary)
                                        .frame(width: dotSize, height: dotSize)
                                        .padding(.bottom, 1)
                                }
                            }
                    } else {
                        Text("")
                            .font(.system(size: dayFont))
                            .frame(maxWidth: .infinity, minHeight: cellMinHeight)
                    }
                }
            }
        }
        .frame(width: gridWidth)
    }
}
