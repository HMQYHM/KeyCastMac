// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyCast",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "KeyCast",
            path: "Sources/KeyCast"
        )
    ]
)
