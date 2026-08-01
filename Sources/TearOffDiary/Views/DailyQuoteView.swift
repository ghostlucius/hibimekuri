import SwiftUI

/// Picks between the Japanese idiom card and the English word-of-the-day
/// card. The word of the day is only ever shown in English mode — it's an
/// alternative for readers who'd rather not have Japanese content at all.
struct DailyQuoteView: View {
    let date: Date
    let quote: Quote?

    @Environment(WordStore.self) private var wordStore
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @AppStorage("quoteStyle") private var quoteStyle: QuoteStyle = .japaneseIdiom

    var body: some View {
        if language == .english, quoteStyle == .englishWord, let word = wordStore.word(for: date) {
            WordOfDayCardView(word: word)
        } else if let quote {
            QuoteCardView(quote: quote)
        }
    }
}
