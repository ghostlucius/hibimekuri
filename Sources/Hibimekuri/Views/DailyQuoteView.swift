import SwiftUI

/// Picks between the Japanese idiom card, the English word-of-the-day card,
/// and a user-imported custom quote card. Word of the day is only ever
/// shown in English mode — it's an alternative for readers who'd rather not
/// have Japanese content at all. Custom falls back to the idiom card when
/// nothing has been imported yet, rather than showing a blank area.
struct DailyQuoteView: View {
    let date: Date
    let quote: Quote?

    @Environment(WordStore.self) private var wordStore
    @Environment(CustomQuoteStore.self) private var customQuoteStore
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @AppStorage("quoteStyle") private var quoteStyle: QuoteStyle = .japaneseIdiom

    var body: some View {
        if language == .english, quoteStyle == .englishWord, let word = wordStore.word(for: date) {
            WordOfDayCardView(word: word)
        } else if quoteStyle == .custom, let customQuote = customQuoteStore.quote(for: date) {
            CustomQuoteCardView(quote: customQuote)
        } else if let quote {
            QuoteCardView(quote: quote)
        }
    }
}
