// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BuJoMode",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BuJoMode",
            path: "Sources/BuJoMode"
        )
    ]
)
