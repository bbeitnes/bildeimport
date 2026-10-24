// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Bildeimport",
    defaultLocalization: "nb",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Bildeimport", targets: ["Bildeimport"])
    ],
    targets: [
        // All import logic: card detection rules, scanning, dates, folder layout,
        // duplicate handling and copying. No UI code here, so it can be unit tested.
        .target(
            name: "ImportCore",
            path: "Sources/ImportCore"
        ),
        // The SwiftUI app itself.
        .executableTarget(
            name: "Bildeimport",
            dependencies: ["ImportCore"],
            path: "Sources/Bildeimport"
        ),
        .testTarget(
            name: "ImportCoreTests",
            dependencies: ["ImportCore"],
            path: "Tests/ImportCoreTests"
        )
    ],
    // Swift 5 language mode keeps concurrency checking at warning level.
    swiftLanguageModes: [.v5]
)
