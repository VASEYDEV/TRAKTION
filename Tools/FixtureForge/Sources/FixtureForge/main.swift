import Foundation
import FixtureForgeKit
import TraktionVision

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

private enum FixtureForgeError: Error, CustomStringConvertible {
  case usage(String)
  case unknownCommand(String)
  case outputExists(String)

  var description: String {
    switch self {
    case .usage(let message):
      return message
    case .unknownCommand(let command):
      return "Unknown command: \(command)"
    case .outputExists(let name):
      return "Refusing to overwrite existing fixture directory: \(name)"
    }
  }
}

private struct FixtureCaptureManifest: Encodable {
  let id: String
  let fileName: String
  let sourceOriginY: Int
  let width: Int
  let height: Int
}

private struct FixtureManifest: Encodable {
  let schemaVersion: Int
  let fixtureName: String
  let axis: String
  let sourceFileName: String
  let sourceWidth: Int
  let sourceHeight: Int
  let captures: [FixtureCaptureManifest]
  let expectedOrder: [String]
  let expectedOverlapRows: [Int]
  let expectedStatus: String
}

private enum FixtureForgeCommand {
  static func run(arguments: [String]) throws {
    guard let command = arguments.first else {
      printHelp()
      return
    }

    switch command {
    case "baseline":
      try writeBaseline(Array(arguments.dropFirst()))
    case "--help", "-h", "help":
      printHelp()
    case "--version", "version":
      print("fixture-forge 0.4.0")
    default:
      throw FixtureForgeError.unknownCommand(command)
    }
  }

  static func writeBaseline(_ arguments: [String]) throws {
    guard arguments.count == 2, arguments[0] == "--output-dir" else {
      throw FixtureForgeError.usage(
        "Usage: fixture-forge baseline --output-dir <directory>"
      )
    }
    let outputURL = URL(fileURLWithPath: arguments[1])
    let fileManager = FileManager.default
    guard !fileManager.fileExists(atPath: outputURL.path) else {
      throw FixtureForgeError.outputExists(outputURL.lastPathComponent)
    }
    try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

    let fixture = try SyntheticFixtureFactory.baseline()
    try PNGCodec.encodeOpaqueRGBA8(
      fixture.source,
      to: outputURL.appendingPathComponent("source.png")
    )
    for capture in fixture.captures {
      try PNGCodec.encodeOpaqueRGBA8(
        capture.image,
        to: outputURL.appendingPathComponent(capture.sourceName)
      )
    }

    let manifest = FixtureManifest(
      schemaVersion: 1,
      fixtureName: fixture.name,
      axis: "vertical",
      sourceFileName: "source.png",
      sourceWidth: fixture.source.width,
      sourceHeight: fixture.source.height,
      captures: fixture.captures.enumerated().map { index, capture in
        FixtureCaptureManifest(
          id: capture.id.rawValue,
          fileName: capture.sourceName,
          sourceOriginY: fixture.sourceOrigins[index],
          width: capture.image.width,
          height: capture.image.height
        )
      },
      expectedOrder: fixture.captures.map(\.id.rawValue),
      expectedOverlapRows: fixture.expectedOverlaps,
      expectedStatus: "exact"
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(manifest).write(
      to: outputURL.appendingPathComponent("fixture.json"),
      options: .atomic
    )
    print("Generated deterministic fixture → \(outputURL.path)")
  }

  static func printHelp() {
    print(
      """
      FixtureForge — deterministic TRAKTION test corpus generator

      Usage:
        fixture-forge baseline --output-dir <directory>
      """
    )
  }
}

do {
  try FixtureForgeCommand.run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch {
  FileHandle.standardError.write(Data("fixture-forge: \(error)\n".utf8))
  exit(EXIT_FAILURE)
}
