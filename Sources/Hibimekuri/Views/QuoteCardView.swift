import SwiftUI

struct QuoteCardView: View {
    let quote: Quote
    @AppStorage("appLanguage") private var language: AppLanguage = .fallback

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sourceLabel.uppercased())
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            // The idiom itself always stays in Japanese — only the app's
            // chrome translates. Other languages add the meaning underneath
            // rather than replacing the original text.
            Text(quote.japanese)
                .font(.system(size: 16, weight: .medium))

            if let meaning = quote.meaning(in: language) {
                Text(meaning)
                    .font(.system(size: 12, weight: .regular))
                    .italic()
                    .foregroundStyle(.secondary)
            }

            if let attribution = quote.attribution {
                Text(verbatim: "— \(attribution)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sourceLabel: String {
        switch quote.source {
        case .proverb: Localizer.t("ことわざ", quote.source.label, language: language)
        case .yojijukugo: Localizer.t("四字熟語", quote.source.label, language: language)
        case .literature: Localizer.t("文学", quote.source.label, language: language)
        }
    }
}
