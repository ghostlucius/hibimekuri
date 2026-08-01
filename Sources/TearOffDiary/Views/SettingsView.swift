import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(QuoteStore.self) private var quoteStore
    @Environment(TaskStore.self) private var taskStore
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @AppStorage("quoteStyle") private var quoteStyle: QuoteStyle = .japaneseIdiom

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("TearOffDiary/entries.json")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section(Localizer.t("言語", "LANGUAGE", language: language)) {
                    HStack(spacing: 8) {
                        ForEach(AppLanguage.allCases) { option in
                            languageButton(option)
                        }
                    }
                }

                if language == .english {
                    HairlineDivider()

                    section("DAILY QUOTE") {
                        HStack(spacing: 8) {
                            ForEach(QuoteStyle.allCases) { option in
                                quoteStyleButton(option)
                            }
                        }
                        Text("Word of the day replaces the Japanese idiom entirely, for readers who'd rather stay in English.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }

                HairlineDivider()

                section(Localizer.t("保存先", "STORAGE", language: language)) {
                    Text(storageURL.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button(Localizer.t("Finderで表示", "Reveal in Finder", language: language)) {
                        NSWorkspace.shared.activateFileViewerSelecting([storageURL])
                    }
                    .font(.system(size: 12))
                }

                HairlineDivider()

                section(Localizer.t("このアプリについて", "ABOUT", language: language)) {
                    Text(Localizer.t("\(store.entries.count) 件の記録", "\(store.entries.count) entries recorded", language: language))
                        .font(.system(size: 12))
                    Text(Localizer.t("\(taskStore.tasks.count) 件のタスク", "\(taskStore.tasks.count) tasks tracked", language: language))
                        .font(.system(size: 12))
                    Text(Localizer.t("\(quoteStore.quotes.count) 件の名言を収録", "\(quoteStore.quotes.count) quotes bundled", language: language))
                        .font(.system(size: 12))
                    Text(Localizer.t(
                        "干支・六曜・十二直・旧暦は天文計算による近似値です。日本の公式暦要項ではありません。",
                        "Almanac fields (kanshi, rokuyō, jūnichoku, kyūreki) are computed from an astronomical approximation, not the official Japanese ephemeris.",
                        language: language))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 4)
            }
            .padding(24)
        }
        .background(DS.paper)
        .frame(width: 440, height: 460)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DS.smallCaption)
                .foregroundStyle(.secondary)
                .tracking(1.2)
            content()
        }
    }

    private func languageButton(_ option: AppLanguage) -> some View {
        Button {
            language = option
        } label: {
            Text(option.displayName)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(language == option ? Color.primary : Color.clear)
                .foregroundStyle(language == option ? DS.paper : Color.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func quoteStyleButton(_ option: QuoteStyle) -> some View {
        Button {
            quoteStyle = option
        } label: {
            Text(option.displayName)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(quoteStyle == option ? Color.primary : Color.clear)
                .foregroundStyle(quoteStyle == option ? DS.paper : Color.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
