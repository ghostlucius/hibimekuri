// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Hibimekuri",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Hibimekuri",
            resources: [.process("Resources")],
            // The tools-version defaults to the Swift 6 language mode, which turns on
            // strict concurrency checking — that's a real, separate
            // codebase-wide migration this change isn't trying to make.
            // Pinning back to .v5 keeps behavior otherwise unchanged.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
