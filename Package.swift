// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TearOffDiary",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TearOffDiary",
            resources: [.process("Resources")]
        )
    ]
)
