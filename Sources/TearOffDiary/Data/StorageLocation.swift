import Foundation

/// Where the JSON stores live: local Application Support by default, or a
/// plain folder under the user's iCloud Drive when "Sync via iCloud" is on
/// in Settings — Finder/iCloud Drive syncs that folder on its own. This is
/// deliberately *not* an app-scoped CloudKit/ubiquity container: that needs
/// an iCloud entitlement tied to a paid Apple Developer account and real
/// code-signing, and this build is ad-hoc signed with no entitlements at
/// all (see requirements.md, "iCloud sync"). Mac-only for now — there's no
/// iOS target in this environment (no Xcode).
enum StorageLocation {
    static let iCloudSyncKey = "iCloudSyncEnabled"

    static var isICloudEnabled: Bool {
        UserDefaults.standard.bool(forKey: iCloudSyncKey)
    }

    static var localDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("TearOffDiary", isDirectory: true)
    }

    /// The user's iCloud Drive root. nil if iCloud Drive isn't set up on
    /// this Mac at all, so callers can fall back to local storage silently.
    private static var iCloudDriveRoot: URL? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return FileManager.default.fileExists(atPath: root.path) ? root : nil
    }

    static var iCloudDirectory: URL? {
        iCloudDriveRoot?.appendingPathComponent("TearOffDiary", isDirectory: true)
    }

    /// True only when the setting is on *and* iCloud Drive is actually
    /// available — the thing callers care about ("are we really syncing").
    static var isUsingICloud: Bool {
        isICloudEnabled && iCloudDirectory != nil
    }

    /// The directory the stores should currently read/write, created if needed.
    static var activeDirectory: URL {
        let dir = (isICloudEnabled ? iCloudDirectory : nil) ?? localDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
