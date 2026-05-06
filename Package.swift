// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuBarApp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "App",
            path: "Sources/App",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
