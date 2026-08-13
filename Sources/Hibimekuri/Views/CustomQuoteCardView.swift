import SwiftUI

struct CustomQuoteCardView: View {
    let quote: CustomQuote
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localizer.t("カスタム", "CUSTOM", language: language))
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            Text(quote.text)
                .font(.system(size: 16, weight: .medium))

            if let attribution = quote.attribution {
                Text(verbatim: "— \(attribution)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
