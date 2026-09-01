import Foundation

/// Resolves SwiftPM's processed resource bundle in both development and a
/// signed macOS app. `Bundle.module` searches beside the `.app`, a location
/// that an application bundle cannot use without invalidating its signature.
enum AppResources {
    private static let bundleName = "Hibimekuri_Hibimekuri.bundle"

    static let bundle: Bundle = {
        let locations = [
            Bundle.main.resourceURL,
            Bundle.main.executableURL?.deletingLastPathComponent(),
            Bundle.main.bundleURL
        ]

        for location in locations.compactMap({ $0 }) {
            if let bundle = Bundle(url: location.appendingPathComponent(bundleName)) {
                return bundle
            }
        }

        // Development builds without processed resources remain usable; data
        // stores simply fall back to their existing empty-state behavior.
        return Bundle.main
    }()
}
