// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexModelSwitcherCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CodexModelSwitcherCore", targets: ["CodexModelSwitcherCore"])
    ],
    targets: [
        .target(
            name: "CodexModelSwitcherCore",
            path: "CodexModelSwitcher/ProfileCore"
        ),
        .executableTarget(
            name: "ProfileCoreTestRunner",
            dependencies: ["CodexModelSwitcherCore"],
            path: "Tests/CodexModelSwitcherCoreTests"
        )
    ]
)
