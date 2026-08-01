import SwiftUI

struct MemoBox: View {
    @Binding var text: String
    var isEditable: Bool = true
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localizer.t("メモ", "MEMO", language: language))
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            ZStack(alignment: .topLeading) {
                if text.isEmpty && isEditable {
                    Text(Localizer.t("今日の振り返りを書く…", "Write today's reflection…", language: language))
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .disabled(!isEditable)
                    .frame(minHeight: 110)
            }
            .padding(6)
            .overlay(
                Rectangle()
                    .stroke(DS.hairline, lineWidth: 1)
            )
        }
    }
}
