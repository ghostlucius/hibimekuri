import SwiftUI

struct QuoteCardView: View {
    let quote: Quote
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sourceLabel.uppercased())
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            // The idiom itself always stays in Japanese — only the app's
            // chrome translates. English mode adds the meaning underneath
            // rather than replacing the original text.
            Text(quote.japanese)
                .font(.system(size: 20, weight: .medium))

            if language == .english {
                Text(quote.english)
                    .font(.system(size: 14, weight: .regular))
                    .italic()
                    .foregroundStyle(.secondary)
            }

            if let attribution = quote.attribution {
                Text(verbatim: "— \(attribution)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sourceLabel: String {
        switch (quote.source, language) {
        case (.proverb, .japanese): return "ことわざ"
        case (.yojijukugo, .japanese): return "四字熟語"
        case (.literature, .japanese): return "文学"
        default: return quote.source.label
        }
    }
}
