import SwiftUI

struct WordOfDayCardView: View {
    let word: WordOfDay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WORD OF THE DAY")
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.word)
                    .font(.system(size: 22, weight: .semibold))
                Text(word.partOfSpeech)
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(.secondary)
            }

            Text(word.definition)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text(verbatim: "“\(word.example)”")
                .font(.system(size: 12))
                .italic()
                .foregroundStyle(.tertiary)
        }
    }
}
