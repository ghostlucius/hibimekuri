import SwiftUI

/// The full himekuri header block: weekday on the left, year/era/month
/// clustered together on the right (matching the physical reference
/// calendar), the giant numeral, and the two side almanac columns —
/// kanshi/rokuyō/kyūreki/moon phase on the left; jūnichoku and the day's
/// observance on the right — with their mini reference calendars. Shared
/// by today's editable page and the archive.
struct DayPageHeader: View {
    let date: Date
    var language: AppLanguage = .japanese

    private var day: CalendarDay { CalendarDay(date: date) }
    private var koyomi: Koyomi.Day { Koyomi.day(for: date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            topRow
            HStack(alignment: .center, spacing: 4) {
                leftColumn
                Spacer(minLength: 2)
                numeral
                Spacer(minLength: 2)
                rightColumn
            }
            miniCalendarRow
        }
    }

    /// Weekday on the left; year, era stack, and month all clustered
    /// together on the right, top to bottom — kept as one group so there's
    /// no dead gap between "year" and "month" the way splitting them
    /// across separate rows created.
    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if language == .japanese {
                    VerticalText(text: day.weekdayLabel(language: .japanese), font: .system(size: 26, weight: .bold))
                    Text(verbatim: "[\(day.weekdayLabel(language: .english).prefix(3).uppercased())]")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(day.weekdayLabel(language: .english))
                        .font(.system(size: 24, weight: .bold))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(verbatim: "\(day.year)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(Localizer.era(day.eraLabel, language: language))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                ForEach(day.priorEraLabels, id: \.self) { label in
                    Text(Localizer.era(label, language: language))
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(day.monthLabel(language: language))
                        .font(.system(size: 26, weight: .bold))
                    Text(verbatim: "(\(Localizer.monthKind(koyomi.monthKind, language: language)))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var numeral: some View {
        Text(day.dayNumber)
            .font(.system(size: 140, weight: .black))
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            AlmanacField(label: Localizer.fieldLabel("干支", language: language), value: Localizer.kanshi(koyomi.kanshi, language: language))
            AlmanacField(label: Localizer.fieldLabel("六曜", language: language), value: Localizer.rokuyo(koyomi.rokuyo, language: language))
            AlmanacField(label: Localizer.fieldLabel("旧暦", language: language), value: Localizer.kyureki(month: koyomi.kyureki.month, day: koyomi.kyureki.day, isLeap: koyomi.kyureki.isLeap, language: language))

            VStack(alignment: .leading, spacing: 1) {
                Image(systemName: koyomi.moonPhaseSymbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(Localizer.moonPhase(koyomi.moonPhaseName, language: language))
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 88, alignment: .leading)
    }

    /// Just jūnichoku (+ its blurb) and the day's observance — year/era
    /// moved up into topRow, grouped with month instead.
    private var rightColumn: some View {
        VStack(alignment: .trailing, spacing: 5) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(Localizer.fieldLabel("中段", language: language))
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(Localizer.junichoku(koyomi.junichoku, language: language))
                    .font(.system(size: 11, weight: .semibold))
                if let blurb = AlmanacExtras.junichokuBlurb(koyomi.junichoku, language: language) {
                    Text(blurb)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let observance = AlmanacExtras.observance(month: day.monthNumber, day: Int(day.dayNumber) ?? 0, language: language) {
                Text(observance)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(width: 88, alignment: .trailing)
    }

    /// Both mini calendars share one row so they land at the same height,
    /// regardless of how tall the almanac text above each column is.
    private var miniCalendarRow: some View {
        HStack(alignment: .top) {
            if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: date) {
                MiniMonthGrid(monthDate: prevMonth, language: language)
                    .frame(width: 92, alignment: .leading)
            }
            Spacer(minLength: 2)
            if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: date) {
                MiniMonthGrid(monthDate: nextMonth, language: language)
                    .frame(width: 92, alignment: .trailing)
            }
        }
    }
}

private struct AlmanacField: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
        }
    }
}
