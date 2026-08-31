// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "TRAKTION",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(name: "TraktionDomain", targets: ["TraktionDomain"]),
    .library(name: "TraktionCore", targets: ["TraktionCore"]),
    .library(name: "TraktionVision", targets: ["TraktionVision"]),
    .library(name: "TraktionUI", targets: ["TraktionUI"]),
    .library(name: "TraktionAI", targets: ["TraktionAI"]),
    .executable(name: "TRAKTION", targets: ["TRAKTIONApp"]),
    .executable(name: "traktion-lab", targets: ["TraktionLab"]),
    .executable(name: "fixture-forge", targets: ["FixtureForge"]),
  ],
  targets: [
    .target(
      name: "TraktionDomain",
      path: "Packages/TraktionDomain/Sources/TraktionDomain"
    ),
    .target(
      name: "TraktionCore",
      dependencies: ["TraktionDomain"],
      path: "Packages/TraktionCore/Sources/TraktionCore"
    ),
    .target(
      name: "TraktionVision",
      dependencies: ["TraktionDomain"],
      path: "Packages/TraktionVision/Sources/TraktionVision"
    ),
    .target(
      name: "TraktionUI",
      dependencies: ["TraktionDomain", "TraktionCore"],
      path: "Packages/TraktionUI/Sources/TraktionUI"
    ),
    .target(
      name: "TraktionAI",
      dependencies: ["TraktionDomain"],
      path: "Packages/TraktionAI/Sources/TraktionAI"
    ),
    .target(
      name: "FixtureForgeKit",
      dependencies: ["TraktionDomain"],
      path: "Tools/FixtureForge/Sources/FixtureForgeKit"
    ),
    .executableTarget(
      name: "TRAKTIONApp",
      dependencies: ["TraktionUI"],
      path: "App/TRAKTION/Sources"
    ),
    .executableTarget(
      name: "TraktionLab",
      dependencies: ["TraktionDomain", "TraktionCore", "TraktionVision"],
      path: "Tools/TraktionLab/Sources"
    ),
    .executableTarget(
      name: "FixtureForge",
      dependencies: ["TraktionDomain", "TraktionVision", "FixtureForgeKit"],
      path: "Tools/FixtureForge/Sources/FixtureForge"
    ),
    .testTarget(
      name: "TraktionDomainTests",
      dependencies: ["TraktionDomain"],
      path: "Tests/Unit/TraktionDomainTests"
    ),
    .testTarget(
      name: "TraktionCoreGoldenTests",
      dependencies: ["TraktionDomain", "TraktionCore", "FixtureForgeKit"],
      path: "Tests/Golden"
    ),
    .testTarget(
      name: "TraktionPerformanceTests",
      dependencies: ["TraktionDomain", "TraktionCore", "FixtureForgeKit"],
      path: "Tests/Performance"
    ),
    .testTarget(
      name: "TraktionVisionIntegrationTests",
      dependencies: ["TraktionDomain", "TraktionVision", "FixtureForgeKit"],
      path: "Tests/Integration"
    ),
  ]
)
