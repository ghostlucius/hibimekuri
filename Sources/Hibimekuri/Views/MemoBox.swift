import SwiftUI

/// The compact page's memo. Editable pages use the same formatted/Markdown
/// editor as task notes and the extended page; archived pages keep the
/// existing non-interactive Markdown renderer.
struct MemoBox: View {
    @Binding var text: String
    var isEditable: Bool = true
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese

    private var renderedMarkdown: AttributedString {
        BlockMarkdownRenderer.render(text)
    }

    var body: some View {
        if isEditable {
            MarkdownNotesField(
                text: $text,
                placeholder: Localizer.t("今日の振り返りを書く…", "Write today's reflection…", language: language),
                sectionTitle: Localizer.t("メモ", "MEMO", language: language),
                minEditorHeight: 96,
                maxEditorHeight: 180
            )
        } else {
            readOnlyMemo
        }
    }

    private var readOnlyMemo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localizer.t("メモ", "MEMO", language: language))
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            Text(renderedMarkdown)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(minHeight: 70, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .overlay(Rectangle().stroke(DS.hairline, lineWidth: 1))
        }
    }
}
