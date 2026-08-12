import SwiftUI

struct OnboardingView: View {
    var onDismiss: () -> Void

    @AppStorage("appLanguage") private var language: AppLanguage = .japanese

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Localizer.t("日々めくり", "Hibimekuri", language: language))
                    .font(.system(size: 28, weight: .black))
                Text(Localizer.t("日々をめくり、今日を残す。", "Turn the page. Keep the day.", language: language))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.textSecondary)
            }

            HairlineDivider()

            VStack(alignment: .leading, spacing: 12) {
                Text(Localizer.t(
                    "日めくりカレンダーは、毎朝一枚をめくり、その日だけを机の上に残す道具です。",
                    "A himekuri calendar is a daily tear-off calendar: each morning leaves only today on the desk.",
                    language: language))
                Text(Localizer.t(
                    "日々めくりは、日めくりに「々」を加えた名前です。一日が日々になり、毎日の記録として積み重なっていきます。",
                    "Hibimekuri adds the Japanese repetition mark to himekuri: one day becomes days, gathered as a record of everyday life.",
                    language: language))
                Text(Localizer.t(
                    "このアプリでは、切り取ることは「今日を終える」合図です。書いたことはアーカイブに残り、次の日が静かに現れます。",
                    "Here, tearing off a page means closing the day. Your note stays in Archive, and the next page quietly appears.",
                    language: language))
                Text(Localizer.t(
                    "追いつきたい時は、今日までまとめて切り取れます。空白の日も、過ぎた一枚として残ります。",
                    "When you need to catch up, the app can tear through the backlog. Blank days still remain as pages that passed.",
                    language: language))
            }
            .font(.system(size: 13))
            .foregroundStyle(DS.text)
            .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                HStack {
                    Spacer()
                    Text(Localizer.t("始める", "Get Started", language: language))
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.0)
                    Spacer()
                }
                .padding(.vertical, 9)
                .overlay(Rectangle().stroke(DS.text, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 420)
        .background(DS.paper)
        .foregroundStyle(DS.text)
    }
}
