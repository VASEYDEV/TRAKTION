import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

private let labSchemaVersion = 1
private let algorithmVersion = "vertical-suffix-prefix-v1"

private enum LabError: Error, CustomStringConvertible {
  case usage(String)
  case unknownCommand(String)
  case unknownOption(String)
  case missingOptionValue(String)
  case outputExists(String)
  case imagesDiffer

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
    case .outputExists(let name):
      return "Refusing to overwrite existing output: \(name)"
    case .imagesDiffer:
      return "Decoded images differ."
    }
  }
}

private struct CaptureManifest: Encodable {
  let id: CaptureID
  let fileName: String
  let width: Int
  let height: Int
}

private struct LabManifest: Encodable {
  let schemaVersion: Int
  let algorithmVersion: String
  let captures: [CaptureManifest]
  let outputFileName: String
  let plan: ReconstructionPlan
}

private struct JointManifest: Encodable {
  let schemaVersion: Int
  let algorithmVersion: String
  let diagnosis: JointDiagnosis
  let differenceFileName: String
}

private struct ReconstructArguments {
  let axis: ReconstructionAxis
  let outputURL: URL
  let manifestURL: URL
  let diagnosticsURL: URL
  let minimumOverlapRows: Int
  let inputURLs: [URL]
}

private enum TraktionLab {
  static func run(arguments: [String]) throws {
    guard let command = arguments.first else {
      printHelp()
      return
    }

    switch command {
    case "reconstruct":
      try reconstruct(parseReconstruct(Array(arguments.dropFirst())))
    case "compare":
      try compare(Array(arguments.dropFirst()))
    case "--help", "-h", "help":
      printHelp()
    case "--version", "version":
      print("traktion-lab 0.4.0")
    default:
      throw LabError.unknownCommand(command)
    }
  }

  static func reconstruct(_ arguments: ReconstructArguments) throws {
    let fileManager = FileManager.default
    for url in [arguments.outputURL, arguments.manifestURL, arguments.diagnosticsURL]
      where fileManager.fileExists(atPath: url.path)
    {
      throw LabError.outputExists(url.lastPathComponent)
    }

    let captures = try arguments.inputURLs.enumerated().map { index, url in
      CaptureAsset(
        id: CaptureID(String(format: "capture-%03d", index + 1)),
        sourceName: url.lastPathComponent,
        image: try PNGCodec.decodeOpaqueRGBA8(from: url)
      )
    }
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(
        minimumOverlapRows: arguments.minimumOverlapRows
      )
    )
    let result = try engine.reconstruct(
      CaptureSequence(captures: captures),
      axis: arguments.axis
    )

    try fileManager.createDirectory(
      at: arguments.outputURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try PNGCodec.encodeOpaqueRGBA8(result.image, to: arguments.outputURL)

    let manifest = LabManifest(
      schemaVersion: labSchemaVersion,
      algorithmVersion: algorithmVersion,
      captures: captures.map {
        CaptureManifest(
          id: $0.id,
          fileName: $0.sourceName,
          width: $0.image.width,
          height: $0.image.height
        )
      },
      outputFileName: arguments.outputURL.lastPathComponent,
      plan: result.plan
    )
    try writeJSON(manifest, to: arguments.manifestURL)

    try fileManager.createDirectory(
      at: arguments.diagnosticsURL,
      withIntermediateDirectories: false
    )
    for index in result.plan.joints.indices {
      let joint = result.plan.joints[index]
      let stem = String(format: "joint-%03d", index + 1)
      let differenceName = "\(stem)-difference.png"
      let differenceURL = arguments.diagnosticsURL.appendingPathComponent(
        differenceName
      )
      let difference = try engine.differenceImage(
        preceding: captures[index],
        following: captures[index + 1],
        joint: joint
      )
      try PNGCodec.encodeOpaqueRGBA8(difference, to: differenceURL)
      try writeJSON(
        JointManifest(
          schemaVersion: labSchemaVersion,
          algorithmVersion: algorithmVersion,
          diagnosis: joint,
          differenceFileName: differenceName
        ),
        to: arguments.diagnosticsURL.appendingPathComponent("\(stem).json")
      )
    }

    print("Reconstructed \(captures.count) captures → \(arguments.outputURL.path)")
    print("Manifest → \(arguments.manifestURL.path)")
    print("Diagnostics → \(arguments.diagnosticsURL.path)")
  }

  static func compare(_ arguments: [String]) throws {
    guard arguments.count == 2 else {
      throw LabError.usage(
        "Usage: traktion-lab compare <expected.png> <actual.png>"
      )
    }
    let expected = try PNGCodec.decodeOpaqueRGBA8(
      from: URL(fileURLWithPath: arguments[0])
    )
    let actual = try PNGCodec.decodeOpaqueRGBA8(
      from: URL(fileURLWithPath: arguments[1])
    )
    guard expected == actual else {
      throw LabError.imagesDiffer
    }
    print("Decoded RGBA pixels match exactly.")
  }

  static func parseReconstruct(_ arguments: [String]) throws -> ReconstructArguments {
    var axis = ReconstructionAxis.vertical
    var outputURL: URL?
    var manifestURL: URL?
    var diagnosticsURL: URL?
    var minimumOverlapRows = 8
    var inputURLs: [URL] = []
    var index = 0

    while index < arguments.count {
      let argument = arguments[index]
      switch argument {
      case "--axis":
        let value = try optionValue(arguments, index: &index, option: argument)
        guard let parsed = ReconstructionAxis(rawValue: value) else {
          throw LabError.usage("Axis must be vertical or horizontal.")
        }
        axis = parsed
      case "--output":
        outputURL = URL(
          fileURLWithPath: try optionValue(arguments, index: &index, option: argument)
        )
      case "--manifest":
        manifestURL = URL(
          fileURLWithPath: try optionValue(arguments, index: &index, option: argument)
        )
      case "--diagnostics-dir":
        diagnosticsURL = URL(
          fileURLWithPath: try optionValue(arguments, index: &index, option: argument)
        )
      case "--minimum-overlap-rows":
        let value = try optionValue(arguments, index: &index, option: argument)
        guard let parsed = Int(value), parsed > 0 else {
          throw LabError.usage("Minimum overlap rows must be a positive integer.")
        }
        minimumOverlapRows = parsed
      default:
        if argument.hasPrefix("-") {
          throw LabError.unknownOption(argument)
        }
        inputURLs.append(URL(fileURLWithPath: argument))
      }
      index += 1
    }

    guard let outputURL else {
      throw LabError.usage("reconstruct requires --output <composite.png>.")
    }
    guard (2...10).contains(inputURLs.count) else {
      throw LabError.usage("reconstruct requires 2-10 input PNG files.")
    }
    let defaultStem = outputURL.deletingPathExtension()
    return ReconstructArguments(
      axis: axis,
      outputURL: outputURL,
      manifestURL: manifestURL
        ?? defaultStem.appendingPathExtension("reconstruction.json"),
      diagnosticsURL: diagnosticsURL
        ?? defaultStem.appendingPathExtension("diagnostics"),
      minimumOverlapRows: minimumOverlapRows,
      inputURLs: inputURLs
    )
  }

  static func optionValue(
    _ arguments: [String],
    index: inout Int,
    option: String
  ) throws -> String {
    let valueIndex = index + 1
    guard valueIndex < arguments.count else {
      throw LabError.missingOptionValue(option)
    }
    index = valueIndex
    return arguments[valueIndex]
  }

  static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
      throw LabError.outputExists(url.lastPathComponent)
    }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(value).write(to: url, options: .atomic)
  }

  static func printHelp() {
    print(
      """
      TRAKTION deterministic reconstruction laboratory

      Usage:
        traktion-lab reconstruct --output <composite.png> [options] <capture-001.png> <capture-002.png> [...]
        traktion-lab compare <expected.png> <actual.png>

      Options:
        --axis vertical|horizontal       Horizontal fails explicitly in Milestone 1.
        --manifest <path>                Reconstruction JSON sidecar.
        --diagnostics-dir <path>         Per-joint JSON and difference PNGs.
        --minimum-overlap-rows <count>   Default: 8.
      """
    )
  }
}

do {
  try TraktionLab.run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch {
  let message = "traktion-lab: \(error)\n"
  FileHandle.standardError.write(Data(message.utf8))
  exit(EXIT_FAILURE)
}
