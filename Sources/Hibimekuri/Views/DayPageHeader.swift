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

    @Environment(TaskStore.self) private var taskStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showMonthFlip = false
    @State private var flipDegrees: Double = 0

    private var day: CalendarDay { CalendarDay(date: date) }
    private var koyomi: Koyomi.Day { Koyomi.day(for: date) }

    /// Days carrying a task due date, normalized to midnight — used to dot
    /// the mini calendars and the flip calendar alike.
    private var dueDates: Set<Date> {
        Set(taskStore.tasks.compactMap { task -> Date? in
            guard task.archivedAt == nil, !task.isDone, let deferDate = task.deferDate else { return nil }
            return Calendar.current.startOfDay(for: deferDate)
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            topRow
            HStack(alignment: .center, spacing: 4) {
                leftColumn
                Spacer(minLength: 8)
                numeralArea
                Spacer(minLength: 8)
                rightColumn
            }
            miniCalendarRow
        }
    }

    /// Tapping the numeral flips it into a full current-month calendar
    /// (matching the visual language of the mini prev/next calendars below),
    /// dotted with due dates; tapping again flips back. The angle jumps to
    /// the opposite side at the invisible edge-on midpoint so swapping the
    /// content there reads as one continuous flip rather than a snap.
    /// Width matches MiniMonthGrid's own `large` size exactly — the fixed
    /// grid width, not just "however much space is left over".
    private static let numeralAreaWidth: CGFloat = 140

    private var numeralArea: some View {
        Button {
            toggleFlip()
        } label: {
            Group {
                if showMonthFlip {
                    MiniMonthGrid(monthDate: date, highlight: date, markedDates: dueDates, language: language, large: true)
                } else {
                    numeral
                }
            }
            .frame(width: Self.numeralAreaWidth, height: 160)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : flipDegrees), axis: (x: 0, y: 1, z: 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Localizer.t("月間カレンダーを切り替え", "Toggle month calendar", language: language))
        // Fixed width AND height so this slot's box is byte-for-byte
        // identical in both states. Before, only height was pinned — the
        // numeral's `.frame(maxWidth: .infinity)` let it greedily claim
        // whatever flexible space was left in the row, while the grid below
        // is a rigid fixed width; those aren't the same number in general,
        // so the row's total width actually changed between states, and
        // since leftColumn/rightColumn come along for the ride, the whole
        // right side visibly slid sideways on every flip. Pinning both
        // states to one constant box removes the ambiguity entirely rather
        // than hoping the two branches happen to size themselves the same.
    }

    private func toggleFlip() {
        guard !reduceMotion else {
            showMonthFlip.toggle()
            flipDegrees = 0
            return
        }
        withAnimation(.easeIn(duration: 0.18)) {
            flipDegrees = 90
        } completion: {
            showMonthFlip.toggle()
            flipDegrees = -90
            withAnimation(.easeOut(duration: 0.18)) {
                flipDegrees = 0
            }
        }
    }

    /// Weekday on the left; year, era stack, and month all clustered
    /// together on the right, top to bottom — kept as one group so there's
    /// no dead gap between "year" and "month" the way splitting them
    /// across separate rows created.
    private var topRow: some View {
        // Restructured 2026-08-02 after repeated failed attempts to *pad*
        // the weekday down to meet month's baseline (28pt, then 60pt, then
        // 64pt — none of it ever actually landed right, because guessing a
        // constant for "however tall the year+era block happens to be" was
        // the wrong tool). Year+era now sits in its own row above,
        // right-aligned; weekday and month are direct siblings in one
        // `HStack(alignment: .firstTextBaseline)` below it — SwiftUI's
        // *built-in* baseline alignment (not a custom guess) reliably
        // aligns direct siblings, which weekday/month never were before
        // (weekday sat in an unrelated leading VStack while month was
        // buried inside the trailing year/era VStack). 大/小 (month
        // length) moved below the month label instead of beside it, per
        // explicit request, which also simplified this row.
        VStack(alignment: .trailing, spacing: 6) {
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
            }

            HStack(alignment: .firstTextBaseline) {
                if language == .japanese {
                    VStack(alignment: .leading, spacing: 2) {
                        VerticalText(
                            text: day.weekdayLabel(language: .japanese),
                            font: DS.displayFont(size: 26, weight: .bold)
                        )
                        Text(verbatim: "[\(day.weekdayLabel(language: .english).prefix(3).uppercased())]")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(day.weekdayLabel(language: .english))
                        .font(DS.displayFont(size: 24, weight: .bold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(day.monthLabel(language: language))
                        .font(DS.displayFont(size: 26, weight: .bold))
                    Text(verbatim: "(\(Localizer.monthKind(koyomi.monthKind, language: language)))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var numeral: some View {
        Text(day.dayNumber)
            .font(DS.displayFont(size: 140, weight: .black))
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            AlmanacField(label: Localizer.fieldLabel("干支", language: language), value: Localizer.kanshi(koyomi.kanshi, language: language))
            AlmanacField(label: Localizer.fieldLabel("六曜", language: language), value: Localizer.rokuyo(koyomi.rokuyo, language: language))
            AlmanacField(label: Localizer.fieldLabel("旧暦", language: language), value: Localizer.kyureki(month: koyomi.kyureki.month, day: koyomi.kyureki.day, isLeap: koyomi.kyureki.isLeap, language: language))

            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: koyomi.moonPhaseSymbol)
                    .font(.system(size: 15))
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
                MiniMonthGrid(monthDate: prevMonth, markedDates: dueDates, language: language)
                    .frame(width: 92, alignment: .leading)
            }
            Spacer(minLength: 2)
            if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: date) {
                MiniMonthGrid(monthDate: nextMonth, markedDates: dueDates, language: language)
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
