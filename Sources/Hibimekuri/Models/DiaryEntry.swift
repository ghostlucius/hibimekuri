import Foundation

struct DiaryEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    /// Normalized to midnight, local calendar day.
    var date: Date
    var journalText: String = ""
    var quoteId: String
    var isCompleted: Bool = false
    var completedAt: Date?

    init(date: Date, quoteId: String) {
        self.date = date
        self.quoteId = quoteId
    }

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
