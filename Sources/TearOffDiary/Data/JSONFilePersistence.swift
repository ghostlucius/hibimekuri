import Foundation

enum JSONFilePersistence {
    private static let backupLimit = 5
    private static let writeLock = NSLock()
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func loadArray<T: Decodable>(_ type: [T].Type, from url: URL) throws -> [T] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    static func writeArray<T: Codable>(_ values: [T], to url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try writeArraySynchronously(values, to: url)
        }.value
    }

    /// Serializes regular saves and retains a validated prior snapshot before
    /// replacing the primary file. A file modified externally into invalid JSON
    /// is never silently overwritten by an in-memory snapshot.
    static func writeArraySynchronously<T: Codable>(_ values: [T], to url: URL) throws {
        writeLock.lock()
        defer { writeLock.unlock() }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try backupVerifiedArrayIfPresent([T].self, at: url)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(values)
        try data.write(to: url, options: .atomic)
    }

    /// Verifies the existing primary file before keeping it as a recovery
    /// snapshot. Throwing on invalid JSON keeps the original intact instead of
    /// replacing it with a potentially stale in-memory copy.
    @discardableResult
    private static func backupVerifiedArrayIfPresent<T: Decodable>(_ type: [T].Type, at url: URL) throws -> URL? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        _ = try loadArray(type, from: url)
        let backupURL = try backupExistingFile(at: url, reason: "previous")
        prunePreviousBackups(for: url)
        return backupURL
    }

    @discardableResult
    static func backupExistingFile(at url: URL, reason: String) throws -> URL? {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return nil }
        let timestamp = timestampFormatter.string(from: Date())
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "json" : url.pathExtension
        var backupURL = url.deletingLastPathComponent().appendingPathComponent("\(baseName).\(reason).\(timestamp).\(ext)")
        var suffix = 1
        while manager.fileExists(atPath: backupURL.path) {
            backupURL = url.deletingLastPathComponent().appendingPathComponent("\(baseName).\(reason).\(timestamp)-\(suffix).\(ext)")
            suffix += 1
        }
        try manager.copyItem(at: url, to: backupURL)
        return backupURL
    }

    private static func prunePreviousBackups(for url: URL) {
        let manager = FileManager.default
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "json" : url.pathExtension
        let prefix = "\(baseName).previous."
        guard let files = try? manager.contentsOfDirectory(
            at: url.deletingLastPathComponent(),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let backups = files.filter {
            $0.pathExtension == ext && $0.lastPathComponent.hasPrefix(prefix)
        }.sorted {
            (modificationDate(for: $0) ?? .distantPast) > (modificationDate(for: $1) ?? .distantPast)
        }

        for backup in backups.dropFirst(backupLimit) {
            try? manager.removeItem(at: backup)
        }
    }

    static func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    static func message(for error: Error, fileName: String, language: AppLanguage) -> String {
        Localizer.t(
            "\(fileName) の保存で問題が発生しました: \(error.localizedDescription)",
            "There was a problem saving \(fileName): \(error.localizedDescription)",
            language: language
        )
    }
}
