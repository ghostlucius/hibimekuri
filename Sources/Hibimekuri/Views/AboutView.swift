import SwiftUI
import AppKit

/// The standard macOS "About Hibimekuri" panel — icon, name, version, and
/// two links — wired to the app-menu's default About item via
/// `HibimekuriApp`'s `Window("about")` scene + `CommandGroup(replacing:
/// .appInfo)`, not just a button buried in Settings. Distinct from
/// `OnboardingView`: that one explains the himekuri philosophy, this one is
/// the plain credits/version panel every Mac app has.
struct AboutView: View {
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    /// The himekuri-philosophy screen used to be reachable from Settings'
    /// old ABOUT section; that section is now purely STATISTICS, so it
    /// lives here instead rather than becoming unreachable after first
    /// launch. Named for what it explains ("What is a himekuri?") rather
    /// than "About …", which would collide with this window's own title.
    @State private var showStory = false

    /// The static brand icon (the 日々 mark), not `NSApp.applicationIconImage`
    /// — that one is live-redrawn to show today's date number
    /// (`AppIconManager`), which would read as a stray random number here
    /// rather than the app's actual logo. Only present in the packaged
    /// `.app` (`scripts/build_dmg.sh` copies it into `Contents/Resources/`
    /// — a plain `swift run` build has no `.icns` to find), so this falls
    /// back to the live Dock icon rather than showing nothing.
    private var appIcon: NSImage {
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let image = NSImage(contentsOfFile: path) {
            return image
        }
        return NSApp.applicationIconImage ?? NSImage()
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 4) {
                Text("Hibimekuri")
                    .font(.system(size: 22, weight: .bold))
                Text(Localizer.t("バージョン \(versionString)", "Version \(versionString)", language: language))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                // Lowercase "himekuri" deliberately — capitalized it reads
                // as easy to misread for "Hibimekuri" (the app's actual
                // proper name), when this is asking about the generic
                // tradition the app is named after, not the app itself.
                actionButton(Localizer.t("日めくりとは", "What is a himekuri?", language: language)) {
                    showStory = true
                }
                actionButton(Localizer.t("ヘルプ", "Help", language: language)) {
                    NSWorkspace.shared.open(Self.documentationURL)
                }
                actionButton(Localizer.t("サポート", "Get support", language: language)) {
                    NSWorkspace.shared.open(Self.repositoryURL)
                }
            }
        }
        .padding(32)
        .frame(width: 320)
        .background(DS.paper)
        .foregroundStyle(DS.text)
        .sheet(isPresented: $showStory) {
            OnboardingView { showStory = false }
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(DS.text.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // Repo is currently private — the link still resolves for anyone with
    // access (the app's own author, right now), and works for everyone
    // once the repo goes public. Not withheld just because it 404s for
    // some visitors today.
    private static let repositoryURL = URL(string: "https://github.com/ghostlucius/hibimekuri")!
    private static let documentationURL = URL(string: "https://github.com/ghostlucius/hibimekuri/blob/main/docs/USER_GUIDE.md")!
}
