import Foundation
import FixtureForgeKit
import TraktionDomain
import TraktionVision

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

private enum FixtureForgeError: Error, CustomStringConvertible {
  case usage(String)
  case unknownCommand(String)
  case unknownOption(String)
  case missingOptionValue(String)
  case invalidOptionValue(option: String, value: String)
  case outputExists(String)

  var description: String {
    switch self {
    case .usage(let message):
      return message
    case .unknownCommand(let command):
      return "Unknown command: \(command)"
    case .unknownOption(let option):
      return "Unknown option: \(option)"
    case .missingOptionValue(let option):
      return "Missing value for option: \(option)"
    case .invalidOptionValue(let option, let value):
      return "Invalid value for \(option): \(value)"
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
    case "generate":
      try writeControlSet(Array(arguments.dropFirst()))
    case "--help", "-h", "help":
      printHelp()
    case "--version", "version":
      print("fixture-forge 0.4.0")
    default:
      throw FixtureForgeError.unknownCommand(command)
    }
  }

  static func writeControlSet(_ arguments: [String]) throws {
    var configuration = FixtureControlConfiguration()
    var variantName: String?
    var outputPath: String?
    var index = 0

    func value(for option: String) throws -> String {
      index += 1
      guard index < arguments.count else {
        throw FixtureForgeError.missingOptionValue(option)
      }
      return arguments[index]
    }
    func integer(for option: String) throws -> Int {
      let raw = try value(for: option)
      guard let parsed = Int(raw), parsed > 0 else {
        throw FixtureForgeError.invalidOptionValue(option: option, value: raw)
      }
      return parsed
    }

    while index < arguments.count {
      let argument = arguments[index]
      switch argument {
      case "--scenario": variantName = try value(for: argument)
      case "--output-dir": outputPath = try value(for: argument)
      case "--source-id": configuration.sourceID = try value(for: argument)
      case "--width": configuration.crossAxisSize = try integer(for: argument)
      case "--viewport": configuration.viewportLength = try integer(for: argument)
      case "--captures": configuration.captureCount = try integer(for: argument)
      case "--overlap": configuration.overlapLength = try integer(for: argument)
      case "--seed":
        let raw = try value(for: argument)
        guard let parsed = UInt64(raw) else {
          throw FixtureForgeError.invalidOptionValue(option: argument, value: raw)
        }
        configuration.seed = parsed
      case "--axis":
        let raw = try value(for: argument)
        guard let parsed = ReconstructionAxis(rawValue: raw) else {
          throw FixtureForgeError.invalidOptionValue(option: argument, value: raw)
        }
        configuration.axis = parsed
      default:
        throw FixtureForgeError.unknownOption(argument)
      }
      index += 1
    }

    guard let variantName, let variant = FixtureVariant.named(variantName) else {
      throw FixtureForgeError.usage(
        "generate requires --scenario <name>; scenarios: \(FixtureVariant.allNames.joined(separator: ", "))"
      )
    }
    guard let outputPath else {
      throw FixtureForgeError.usage("generate requires --output-dir <directory>")
    }
    configuration.variant = variant

    let outputURL = URL(fileURLWithPath: outputPath)
    let fileManager = FileManager.default
    guard !fileManager.fileExists(atPath: outputURL.path) else {
      throw FixtureForgeError.outputExists(outputURL.lastPathComponent)
    }
    let bundle = try FixtureControlGenerator.generate(configuration)
    try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
    try PNGCodec.encodeOpaqueRGBA8(
      bundle.source,
      to: outputURL.appendingPathComponent(bundle.groundTruth.sourceFileName)
    )
    for capture in bundle.captures {
      try PNGCodec.encodeOpaqueRGBA8(
        capture.image,
        to: outputURL.appendingPathComponent(capture.sourceName)
      )
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(bundle.groundTruth).write(
      to: outputURL.appendingPathComponent("fixture.json"),
      options: .atomic
    )
    let expectation = bundle.groundTruth.expectedFailureCode.map { "expect \($0)" }
      ?? "expect reconstruction"
    print("Generated \(bundle.groundTruth.fixtureName) → \(outputURL.path) (\(expectation))")
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
        fixture-forge generate --scenario <name> --output-dir <directory> [options]

      Scenarios:
        baseline, duplicate-capture, reversed-order, missing-middle,
        sticky-header, sticky-footer, floating-control, scrollbar,
        one-pixel-offset, degraded

      Generate options (defaults in parentheses):
        --source-id <name> (control)     --width <px> (64)
        --viewport <px> (96)             --captures <count> (3)
        --overlap <px> (24)              --seed <uint64> (1414677067)
        --axis vertical|horizontal (vertical; horizontal fixtures expect
                                         the engine's unsupportedAxis failure)
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
