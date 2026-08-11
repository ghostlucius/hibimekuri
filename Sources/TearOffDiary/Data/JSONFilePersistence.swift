import Foundation

enum JSONFilePersistence {
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
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

    static func writeArray<T: Encodable>(_ values: [T], to url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try writeArraySynchronously(values, to: url)
        }.value
    }

    static func writeArraySynchronously<T: Encodable>(_ values: [T], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(values)
        try data.write(to: url, options: .atomic)
    }

    @discardableResult
    static func backupExistingFile(at url: URL, reason: String) throws -> URL? {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return nil }
        let timestamp = timestampFormatter.string(from: Date())
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "json" : url.pathExtension
        let backupName = "\(baseName).\(reason).\(timestamp).\(ext)"
        let backupURL = url.deletingLastPathComponent().appendingPathComponent(backupName)
        try manager.copyItem(at: url, to: backupURL)
        return backupURL
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
