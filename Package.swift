// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pendown",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "Pendown",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            exclude: ["Info.plist", "Info-SPM.plist", "AppIcon.icns", "Pendown.entitlements",
                       "Assets.xcassets"]
        ),
    ]
)
