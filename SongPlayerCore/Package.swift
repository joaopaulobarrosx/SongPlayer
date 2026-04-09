// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SongPlayerCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SongPlayerCore",
            targets: ["SongPlayerCore"]
        ),
    ],
    targets: [
        .target(
            name: "SongPlayerCore",
            path: "Sources/SongPlayerCore"
        ),
        .testTarget(
            name: "SongPlayerCoreTests",
            dependencies: ["SongPlayerCore"],
            path: "Tests/SongPlayerCoreTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
