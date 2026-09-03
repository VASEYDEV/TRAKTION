import Foundation
import TraktionCore
import TraktionDomain
import TraktionLabEvaluation
import TraktionVision

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

private let labSchemaVersion = 3
private let algorithmVersion = "vertical-suffix-prefix-v1"

private enum LabError: Error, CustomStringConvertible {
  case usage(String)
  case unknownCommand(String)
  case unknownOption(String)
  case missingOptionValue(String)
  case outputExists(String)
  case imagesDiffer
  case reconstructionFailed(failureDescription: String, manifestPath: String)
  case failureUnpublished(failureDescription: String, writeError: String)
  case evaluationGateFailed(reportPath: String)

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
    case .reconstructionFailed(let failureDescription, let manifestPath):
      return "\(failureDescription)\nFailure manifest → \(manifestPath)"
    case .failureUnpublished(let failureDescription, let writeError):
      return "\(failureDescription)\nAdditionally, the failure manifest could not be written: \(writeError)"
    case .evaluationGateFailed(let reportPath):
      return "Evaluation gate failed (false-safe, false-warning, wrong-failure, or nondeterminism); see \(reportPath)"
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
  let status: String
  /// How the capture order was established (docs/tasks/0008): `supplied`
  /// (argument order) or `exact` (recovered from byte-exact evidence).
  let orderPolicy: OrderPolicy
  /// Capture IDs in recovered order; absent for supplied-order runs.
  let recoveredOrder: [CaptureID]?
  /// Captures in reconstruction order (the recovered order under `exact`,
  /// otherwise the supplied order), so joints pair true neighbors.
  let captures: [CaptureManifest]
  let outputFileName: String
  let plan: ReconstructionPlan
}

/// Written to the manifest path when decoding or reconstruction fails with a
/// typed error, so a failed run always leaves a deterministic machine-readable
/// record (docs/tasks/0002). Publication (IO) failures keep the
/// clean-and-retry behavior instead.
private struct FailureManifest: Encodable {
  let schemaVersion: Int
  let algorithmVersion: String
  let status: String
  let orderPolicy: OrderPolicy
  /// "decode" (an input could not be loaded) or "reconstruct" (typed engine failure).
  let stage: String
  let failureCode: String
  let failureDescription: String
  /// Present for the reconstruct stage only.
  let reconstructionFailure: ReconstructionFailure?
  /// Captures successfully decoded before the failure, in supplied order.
  let captures: [CaptureManifest]
  let inputFileNames: [String]
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
  let orderPolicy: OrderPolicy
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
    case "evaluate":
      try evaluate(Array(arguments.dropFirst()))
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

    var captures: [CaptureAsset] = []
    captures.reserveCapacity(arguments.inputURLs.count)
    for (index, url) in arguments.inputURLs.enumerated() {
      do {
        captures.append(
          CaptureAsset(
            id: CaptureID(String(format: "capture-%03d", index + 1)),
            sourceName: url.lastPathComponent,
            image: try PNGCodec.decodeOpaqueRGBA8(from: url)
          )
        )
      } catch let error as PNGCodecError {
        try publishFailure(
          arguments,
          stage: "decode",
          failureCode: failureCode(for: error),
          failureDescription: String(describing: error),
          reconstructionFailure: nil,
          captures: captures
        )
      }
    }

    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(
        minimumOverlapRows: arguments.minimumOverlapRows
      )
    )
    let result: ReconstructionResult
    var recoveredOrder: [CaptureID]?
    do {
      switch arguments.orderPolicy {
      case .supplied:
        result = try engine.reconstruct(
          CaptureSequence(captures: captures),
          axis: arguments.axis
        )
      case .exact:
        result = try engine.reconstructExactUnordered(captures, axis: arguments.axis)
        // The plan's placements are the recovered documentary order. Reorder
        // for the manifest and per-joint diagnostics, which pair adjacent
        // captures; IDs are unique by construction (capture-NNN).
        let order = result.plan.placements.map(\.captureID)
        let byID = Dictionary(uniqueKeysWithValues: captures.map { ($0.id, $0) })
        var ordered: [CaptureAsset] = []
        ordered.reserveCapacity(order.count)
        for id in order {
          guard let capture = byID[id] else {
            throw ReconstructionFailure.invalidPlan(
              reason: "recovered order names unknown capture \(id)"
            )
          }
          ordered.append(capture)
        }
        captures = ordered
        recoveredOrder = order
      }
    } catch let failure as ReconstructionFailure {
      try publishFailure(
        arguments,
        stage: "reconstruct",
        failureCode: failure.code,
        failureDescription: failure.description,
        reconstructionFailure: failure,
        captures: captures
      )
    }

    let manifest = LabManifest(
      schemaVersion: labSchemaVersion,
      algorithmVersion: algorithmVersion,
      status: "reconstructed",
      orderPolicy: arguments.orderPolicy,
      recoveredOrder: recoveredOrder,
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

    let artifactURLs = [
      arguments.outputURL,
      arguments.manifestURL,
      arguments.diagnosticsURL,
    ]
    do {
      try fileManager.createDirectory(
        at: arguments.outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try PNGCodec.encodeOpaqueRGBA8(result.image, to: arguments.outputURL)
      try writeJSON(manifest, to: arguments.manifestURL)

      try fileManager.createDirectory(
        at: arguments.diagnosticsURL,
        withIntermediateDirectories: true
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
    } catch {
      for url in artifactURLs.reversed()
        where fileManager.fileExists(atPath: url.path)
      {
        try? fileManager.removeItem(at: url)
      }
      throw error
    }

    print("Reconstructed \(captures.count) captures → \(arguments.outputURL.path)")
    print("Manifest → \(arguments.manifestURL.path)")
    print("Diagnostics → \(arguments.diagnosticsURL.path)")
  }

  /// Writes the failure manifest to the manifest path, then throws the
  /// user-facing error. Never returns: a typed failure always ends the run,
  /// with the manifest as its durable record. If even the manifest cannot be
  /// written, the original failure is still reported.
  static func publishFailure(
    _ arguments: ReconstructArguments,
    stage: String,
    failureCode: String,
    failureDescription: String,
    reconstructionFailure: ReconstructionFailure?,
    captures: [CaptureAsset]
  ) throws -> Never {
    let manifest = FailureManifest(
      schemaVersion: labSchemaVersion,
      algorithmVersion: algorithmVersion,
      status: "failed",
      orderPolicy: arguments.orderPolicy,
      stage: stage,
      failureCode: failureCode,
      failureDescription: failureDescription,
      reconstructionFailure: reconstructionFailure,
      captures: captures.map {
        CaptureManifest(
          id: $0.id,
          fileName: $0.sourceName,
          width: $0.image.width,
          height: $0.image.height
        )
      },
      inputFileNames: arguments.inputURLs.map(\.lastPathComponent)
    )
    do {
      try writeJSON(manifest, to: arguments.manifestURL)
    } catch {
      throw LabError.failureUnpublished(
        failureDescription: failureDescription,
        writeError: String(describing: error)
      )
    }
    throw LabError.reconstructionFailed(
      failureDescription: failureDescription,
      manifestPath: arguments.manifestURL.path
    )
  }

  static func failureCode(for error: PNGCodecError) -> String {
    switch error {
    case .unsupportedPlatform: return "unsupportedPlatform"
    case .fileNotFound: return "fileNotFound"
    case .outputExists: return "outputExists"
    case .unsupportedFormat: return "unsupportedFormat"
    case .unsupportedTransparency: return "unsupportedTransparency"
    case .resourceLimitExceeded: return "resourceLimitExceeded"
    case .decodeFailed: return "decodeFailed"
    case .encodeFailed: return "encodeFailed"
    }
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

  /// Runs the standard evaluation corpus (docs/tasks/0004) and writes the
  /// metrics report. Exits non-zero when the summary is unacceptable —
  /// any false-safe, false-warning, wrong-failure, or nondeterminism.
  static func evaluate(_ arguments: [String]) throws {
    guard arguments.count == 2, arguments[0] == "--output" else {
      throw LabError.usage("Usage: traktion-lab evaluate --output <report.json>")
    }
    let reportURL = URL(fileURLWithPath: arguments[1])

    let report = try EvaluationHarness.evaluate()
    try writeJSON(report, to: reportURL)

    let summary = report.summary
    print("Evaluation report → \(reportURL.path)")
    print(
      "cases: \(summary.cases)  pass: \(summary.pass)  false-safe: \(summary.falseSafe)  "
        + "false-warning: \(summary.falseWarning)  wrong-failure: \(summary.wrongFailure)  "
        + "nondeterministic: \(summary.nondeterministic)"
    )
    let ordering = summary.ordering
    print(
      "ordering: cases \(ordering.cases)  "
        + "correct-sequence \(ordering.sequencesCorrect)/\(ordering.sequencesExpected)  "
        + "duplicates \(ordering.duplicatesIdentified)/\(ordering.duplicatesExpected)  "
        + "missing-captures \(ordering.missingCapturesDetected)/\(ordering.missingCapturesExpected)"
    )
    guard summary.isAcceptable else {
      throw LabError.evaluationGateFailed(reportPath: reportURL.path)
    }
  }

  static func parseReconstruct(_ arguments: [String]) throws -> ReconstructArguments {
    var axis = ReconstructionAxis.vertical
    var outputURL: URL?
    var manifestURL: URL?
    var diagnosticsURL: URL?
    var minimumOverlapRows = 8
    var orderPolicy = OrderPolicy.supplied
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
      case "--order":
        let value = try optionValue(arguments, index: &index, option: argument)
        guard let parsed = OrderPolicy(rawValue: value) else {
          throw LabError.usage(
            "Order policy must be one of: "
              + OrderPolicy.allCases.map(\.rawValue).joined(separator: ", ") + "."
          )
        }
        orderPolicy = parsed
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
      orderPolicy: orderPolicy,
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
        traktion-lab evaluate --output <report.json>

      Options:
        --axis vertical|horizontal       Horizontal fails explicitly in Milestone 1.
        --manifest <path>                Reconstruction JSON sidecar.
        --diagnostics-dir <path>         Per-joint JSON and difference PNGs.
        --minimum-overlap-rows <count>   Default: 8.
        --order supplied|exact           supplied (default): reconstruct in
                                         argument order. exact: recover the
                                         order from byte-exact suffix/prefix
                                         evidence only; gaps and ambiguity
                                         fail closed (ADR-014).
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
