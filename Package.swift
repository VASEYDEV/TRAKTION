// swift-tools-version: 6.0
// TRAKTION — single SwiftPM package, multiple targets (see docs/adr/ADR-011).
// Target paths follow the repository layout in docs/ARCHITECTURE.md.
// App shell and TraktionUI require SwiftUI and are only declared on macOS hosts,
// so the deterministic core builds and tests on Linux as well.
import PackageDescription

var products: [Product] = [
    .library(name: "TraktionDomain", targets: ["TraktionDomain"]),
    .library(name: "TraktionCore", targets: ["TraktionCore"]),
    .library(name: "TraktionVision", targets: ["TraktionVision"]),
    .library(name: "TraktionAI", targets: ["TraktionAI"]),
    .executable(name: "traktion-lab", targets: ["TraktionLabCLI"]),
    .executable(name: "fixtureforge", targets: ["FixtureForgeCLI"]),
]

var targets: [Target] = [
    // MARK: Packages
    .target(
        name: "TraktionDomain",
        path: "Packages/TraktionDomain/Sources"
    ),
    .target(
        name: "TraktionCore",
        dependencies: ["TraktionDomain"],
        path: "Packages/TraktionCore/Sources"
    ),
    .target(
        name: "TraktionVision",
        dependencies: ["TraktionDomain"],
        path: "Packages/TraktionVision/Sources"
    ),
    .target(
        name: "TraktionAI",
        dependencies: ["TraktionDomain"],
        path: "Packages/TraktionAI/Sources"
    ),

    // MARK: Tools (Kit library + thin CLI so tests exercise the shipping code)
    .target(
        name: "FixtureForgeKit",
        dependencies: ["TraktionDomain", "TraktionCore", "TraktionVision"],
        path: "Tools/FixtureForge/Sources/FixtureForgeKit"
    ),
    .executableTarget(
        name: "FixtureForgeCLI",
        dependencies: ["FixtureForgeKit"],
        path: "Tools/FixtureForge/Sources/CLI"
    ),
    .target(
        name: "TraktionLabKit",
        dependencies: ["TraktionDomain", "TraktionCore", "TraktionVision"],
        path: "Tools/TraktionLab/Sources/TraktionLabKit"
    ),
    .executableTarget(
        name: "TraktionLabCLI",
        dependencies: ["TraktionLabKit"],
        path: "Tools/TraktionLab/Sources/CLI"
    ),

    // MARK: Tests
    .testTarget(
        name: "TraktionDomainTests",
        dependencies: ["TraktionDomain"],
        path: "Tests/Unit/TraktionDomainTests"
    ),
    .testTarget(
        name: "TraktionCoreTests",
        dependencies: ["TraktionCore"],
        path: "Tests/Unit/TraktionCoreTests"
    ),
    .testTarget(
        name: "TraktionVisionTests",
        dependencies: ["TraktionVision"],
        path: "Tests/Unit/TraktionVisionTests"
    ),
    .testTarget(
        name: "TraktionAITests",
        dependencies: ["TraktionAI"],
        path: "Tests/Unit/TraktionAITests"
    ),
    .testTarget(
        name: "FixtureForgeKitTests",
        dependencies: ["FixtureForgeKit"],
        path: "Tests/Unit/FixtureForgeKitTests"
    ),
    .testTarget(
        name: "GoldenTests",
        dependencies: ["FixtureForgeKit", "TraktionLabKit"],
        path: "Tests/Golden"
    ),
    .testTarget(
        name: "PerformanceTests",
        dependencies: ["FixtureForgeKit", "TraktionLabKit", "TraktionVision"],
        path: "Tests/Performance"
    ),
]

#if os(macOS)
products += [
    .library(name: "TraktionUI", targets: ["TraktionUI"]),
    .executable(name: "TRAKTION", targets: ["TraktionApp"]),
]
targets += [
    .target(
        name: "TraktionUI",
        dependencies: ["TraktionDomain"],
        path: "Packages/TraktionUI/Sources"
    ),
    .executableTarget(
        name: "TraktionApp",
        dependencies: ["TraktionUI", "TraktionDomain"],
        path: "App/TRAKTION/Sources"
    ),
]
#endif

let package = Package(
    name: "Traktion",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
