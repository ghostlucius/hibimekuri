import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(QuoteStore.self) private var quoteStore
    @Environment(TaskStore.self) private var taskStore
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appLanguage") private var language: AppLanguage = .japanese
    @AppStorage("quoteStyle") private var quoteStyle: QuoteStyle = .japaneseIdiom
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system
    @AppStorage(StorageLocation.iCloudSyncKey) private var iCloudSyncEnabled: Bool = false
    @AppStorage("taskRetentionDays") private var taskRetention: TaskRetention = .thirtyDays
    @State private var showArchivedTasks = false
    @State private var exportMessage: String?
    @State private var showOnboarding = false

    private var storageURL: URL {
        store.storageDirectory.appendingPathComponent("entries.json")
    }

    private var iCloudDriveAvailable: Bool {
        StorageLocation.iCloudDirectory != nil
    }

    /// Most recently deleted first — that's the one someone's most likely
    /// looking to undo.
    private var archivedTasks: [TaskItem] {
        taskStore.tasks
            .filter { $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
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

                HairlineDivider()

                // Theme (which palette) and Mode (Light/Dark/System) are
                // two facets of one thing the user is choosing — how the
                // app looks — so they live under one master "Appearance"
                // category instead of two parallel top-level sections.
                section(Localizer.t("外観", "APPEARANCE", language: language)) {
                    subLabel(Localizer.t("テーマ", "Theme", language: language))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(DiaryTheme.allCases) { option in
                            themeSwatchButton(option)
                        }
                    }

                    subLabel(Localizer.t("モード", "Mode", language: language))
                        .padding(.top, 4)
                    HStack(spacing: 8) {
                        ForEach(AppAppearance.allCases) { option in
                            appearanceButton(option)
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

                section(Localizer.t("タスク", "TASKS", language: language)) {
                    subLabel(Localizer.t("削除したタスクの保存期間", "Deleted task retention", language: language))
                    HStack(spacing: 8) {
                        ForEach(TaskRetention.allCases) { option in
                            retentionButton(option)
                        }
                    }

                    if !archivedTasks.isEmpty {
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { showArchivedTasks.toggle() }
                        } label: {
                            Text(Localizer.t(
                                "最近削除した項目（\(archivedTasks.count)件）",
                                "Recently deleted (\(archivedTasks.count))",
                                language: language))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        .accessibilityValue(showArchivedTasks
                            ? Localizer.t("展開中", "Expanded", language: language)
                            : Localizer.t("折りたたみ中", "Collapsed", language: language))

                        if showArchivedTasks {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(archivedTasks) { task in
                                    HStack {
                                        Text(task.title)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(Localizer.t("復元", "Restore", language: language)) {
                                            taskStore.restore(task.id)
                                        }
                                        .font(.system(size: 11))
                                    }
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                HairlineDivider()

                section(Localizer.t("保存先", "STORAGE", language: language)) {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        Text(Localizer.t("iCloudで同期", "Sync via iCloud", language: language))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .toggleStyle(.switch)
                    .onChange(of: iCloudSyncEnabled) { _, _ in
                        store.relocateStorage()
                        taskStore.relocateStorage()
                    }

                    if iCloudSyncEnabled && !iCloudDriveAvailable {
                        Text(Localizer.t(
                            "このMacではiCloud Driveが利用できないため、データはローカルに保存されます。",
                            "iCloud Drive isn't available on this Mac, so data is staying local for now.",
                            language: language))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(Localizer.t(
                            "オンにすると、同じiCloudアカウントの他のMacとデータを共有します。オフの場合はこのMacだけに保存されます。",
                            "When on, other Macs signed into the same iCloud account share this data. When off, it stays on this Mac only.",
                            language: language))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Text(storageURL.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 2)

                    if let issue = store.storageIssueMessage {
                        storageIssue(issue)
                    }
                    if let issue = taskStore.storageIssueMessage {
                        storageIssue(issue)
                    }

                    Button(Localizer.t("Finderで表示", "Reveal in Finder", language: language)) {
                        NSWorkspace.shared.activateFileViewerSelecting([storageURL])
                    }
                    .font(.system(size: 12))

                    Button(Localizer.t("データを書き出す", "Export Data", language: language)) {
                        exportData()
                    }
                    .font(.system(size: 12))

                    if let exportMessage {
                        Text(exportMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                HairlineDivider()

                section(Localizer.t("このアプリについて", "ABOUT", language: language)) {
                    Button(Localizer.t("日めくりについて", "About Himekuri", language: language)) {
                        showOnboarding = true
                    }
                    .font(.system(size: 12))
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
        .foregroundStyle(DS.text)
        .frame(width: 440, height: 460)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
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

    /// A smaller label for a sub-group within a `section`, e.g. "Theme" and
    /// "Mode" inside the master "Appearance" section.
    private func subLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .tracking(0.8)
    }

    private func storageIssue(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11))
            .foregroundStyle(Color.red)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(message)
    }

    private func languageButton(_ option: AppLanguage) -> some View {
        Button {
            language = option
        } label: {
            Text(option.displayName)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(language == option ? DS.text : Color.clear)
                .foregroundStyle(language == option ? DS.paper : DS.text)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DS.text.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(language == option ? .isSelected : [])
    }

    /// Color, not text, is the differentiator between themes, so this uses
    /// a small swatch preview (the theme's own light palette) instead of
    /// the text-pill style used elsewhere in this screen — six text pills
    /// ("Classic"/"Matcha"/"Washi"/"Sumi"/"Zen"/"Sakura") wouldn't fit this
    /// window's width anyway.
    private func themeSwatchButton(_ option: DiaryTheme) -> some View {
        let palette = option.definition.light
        let isSelected = themeManager.theme == option
        // Classic's illustration deliberately renders in plain black/white
        // (its own textPrimary) instead of a colored accent, matching its
        // "simple black and white" identity — the swatch dot needs the
        // same exception, or it shows a reddish dot for a theme that
        // actually renders monochrome, which read as if Classic and
        // Sumi's colors had been swapped.
        let dotColor = option == .classic ? palette.textPrimary : palette.accentStrong

        return Button {
            themeManager.theme = option
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.background)
                    .frame(height: 36)
                    .overlay(
                        Circle()
                            .fill(dotColor)
                            .frame(width: 10, height: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isSelected ? DS.text : DS.text.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )

                Text(option.displayName(language: language))
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? DS.text : DS.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName(language: language))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func appearanceButton(_ option: AppAppearance) -> some View {
        Button {
            appearance = option
        } label: {
            Text(option.displayName(language: language))
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(appearance == option ? DS.text : Color.clear)
                .foregroundStyle(appearance == option ? DS.paper : DS.text)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DS.text.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(appearance == option ? .isSelected : [])
    }

    private func retentionButton(_ option: TaskRetention) -> some View {
        Button {
            taskRetention = option
        } label: {
            Text(option.displayName(language: language))
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(taskRetention == option ? DS.text : Color.clear)
                .foregroundStyle(taskRetention == option ? DS.paper : DS.text)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DS.text.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(taskRetention == option ? .isSelected : [])
    }

    private func quoteStyleButton(_ option: QuoteStyle) -> some View {
        Button {
            quoteStyle = option
        } label: {
            Text(option.displayName)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(quoteStyle == option ? DS.text : Color.clear)
                .foregroundStyle(quoteStyle == option ? DS.paper : DS.text)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DS.text.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(quoteStyle == option ? .isSelected : [])
    }

    private func exportData() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = Localizer.t("書き出す", "Export", language: language)

        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            let entriesDirectory = store.storageDirectory
            let tasksDirectory = taskStore.storageDirectory
            let currentLanguage = language

            Task.detached {
                do {
                    try Self.copyStoreFile(named: "entries.json", from: entriesDirectory, to: destination)
                    try Self.copyStoreFile(named: "tasks.json", from: tasksDirectory, to: destination)
                    await MainActor.run {
                        let message = Localizer.t("書き出しが完了しました。", "Export complete.", language: currentLanguage)
                        exportMessage = message
                        announceExportMessage(message)
                    }
                } catch {
                    await MainActor.run {
                        let message = Localizer.t("書き出しに失敗しました。", "Export failed.", language: currentLanguage)
                        exportMessage = message
                        announceExportMessage(message)
                    }
                }
            }
        }
    }

    private func announceExportMessage(_ message: String) {
        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: message]
        )
    }

    nonisolated private static func copyStoreFile(named fileName: String, from sourceDirectory: URL, to destinationDirectory: URL) throws {
        let source = sourceDirectory.appendingPathComponent(fileName)
        let destination = destinationDirectory.appendingPathComponent(fileName)
        let manager = FileManager.default
        if manager.fileExists(atPath: destination.path) {
            try manager.removeItem(at: destination)
        }
        if manager.fileExists(atPath: source.path) {
            try manager.copyItem(at: source, to: destination)
        } else {
            try Data("[]".utf8).write(to: destination, options: .atomic)
        }
    }
}
