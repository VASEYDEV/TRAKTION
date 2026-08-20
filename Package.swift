// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TRAKTION",
  platforms: [.macOS(.v13), .iOS(.v16)],
  products: [
    .library(name: "TraktionDomain", targets: ["TraktionDomain"]),
    .library(name: "TraktionCore", targets: ["TraktionCore"]),
    .library(name: "TraktionVision", targets: ["TraktionVision"]),
    .library(name: "TraktionUI", targets: ["TraktionUI"]),
    .library(name: "TraktionAI", targets: ["TraktionAI"]),
    .executable(name: "traktion-lab", targets: ["TraktionLab"]),
    .executable(name: "fixture-forge", targets: ["FixtureForge"]),
    .executable(name: "TRAKTION", targets: ["TRAKTIONApp"]),
  ],
  targets: [
    .systemLibrary(
      name: "CZlib", path: "Sources/CZlib", pkgConfig: "zlib",
      providers: [.apt(["zlib1g-dev"]), .brew(["zlib"])]),
    .target(name: "TraktionDomain", path: "Packages/TraktionDomain/Sources/TraktionDomain"),
    .target(
      name: "TraktionVision", dependencies: ["TraktionDomain", "CZlib"],
      path: "Packages/TraktionVision/Sources/TraktionVision"),
    .target(
      name: "TraktionCore", dependencies: ["TraktionDomain", "TraktionVision"],
      path: "Packages/TraktionCore/Sources/TraktionCore"),
    .target(
      name: "TraktionAI", dependencies: ["TraktionDomain"],
      path: "Packages/TraktionAI/Sources/TraktionAI"),
    .executableTarget(name: "TRAKTIONApp", dependencies: ["TraktionUI"], path: "App/TRAKTION"),
    .target(
      name: "TraktionUI", dependencies: ["TraktionDomain", "TraktionCore"],
      path: "Packages/TraktionUI/Sources/TraktionUI"),
    .executableTarget(
      name: "TraktionLab", dependencies: ["TraktionCore", "TraktionVision"],
      path: "Tools/TraktionLab/Sources/TraktionLab"),
    .executableTarget(
      name: "FixtureForge", dependencies: ["TraktionVision"],
      path: "Tools/FixtureForge/Sources/FixtureForge"),
    .testTarget(
      name: "TraktionCoreTests", dependencies: ["TraktionCore", "TraktionVision"],
      path: "Tests/TraktionCoreTests"),
  ]
)
