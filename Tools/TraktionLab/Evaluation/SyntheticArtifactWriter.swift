import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision

/// Diagnostic-only output. Callers must supply generated synthetic evidence;
/// this writer is deliberately not part of the app's reconstruction path.
public enum SyntheticArtifactOutcome {
  case reconstructed(ReconstructionResult)
  case failed(ReconstructionFailure)
  case unexpectedError(String)
}

public struct EvaluationArtifactOptions {
  public let directory: URL
  public let includePassingCases: Bool

  public init(directory: URL, includePassingCases: Bool = false) {
    self.directory = directory
    self.includePassingCases = includePassingCases
  }
}

public enum SyntheticArtifactError: Error, CustomStringConvertible {
  case invalidCaseName(String)
  case outputExists(String)
  case missingCapture(String)
  case publicationFailed(caseName: String, reason: String)

  public var description: String {
    switch self {
    case .invalidCaseName(let name): return "Unsafe synthetic artifact case name: \(name)"
    case .outputExists(let path): return "Refusing to overwrite synthetic artifacts: \(path)"
    case .missingCapture(let id): return "Diagnostic joint refers to missing capture: \(id)"
    case .publicationFailed(let name, let reason):
      return "Could not publish synthetic artifacts for \(name): \(reason)"
    }
  }
}

public enum SyntheticArtifactWriter {
  private struct Size: Encodable {
    let width: Int
    let height: Int
    init(_ image: RasterImage) {
      width = image.width
      height = image.height
    }
  }

  private struct Capture: Encodable {
    let id: CaptureID
    let width: Int
    let height: Int
  }

  private struct Manifest: Encodable {
    let schemaVersion = 1
    let provenance = "synthetic-only"
    let caseName: String
    let status: String
    let assessment: EvaluationCaseResult?
    let expectedSize: Size
    let actualSize: Size?
    /// Top-left common extent. Full original rasters are always retained.
    let differenceExtent: Size?
    let differenceOrigin = "top-left"
    let unavailableArtifacts: [String: String]
    let captures: [Capture]
    let plan: ReconstructionPlan?
    let reconstructionFailure: ReconstructionFailure?
    let unexpectedError: String?
  }

  private struct JointManifest: Encodable {
    let schemaVersion = 1
    let diagnosis: JointDiagnosis
    let differenceFileName: String
  }

  static func validateCaseName(_ name: String) throws {
    let allowed = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
    guard !name.isEmpty, name != ".", name != "..", name.utf8.count <= 160,
      name.unicodeScalars.allSatisfy({ allowed.contains($0) })
    else { throw SyntheticArtifactError.invalidCaseName(name) }
  }

  /// Publishes a new case directory only after every file has been written.
  /// Existing directories (including symlinks) are never removed or reused.
  public static func write(
    caseName: String,
    expected: RasterImage,
    captures: [CaptureAsset],
    outcome: SyntheticArtifactOutcome,
    assessment: EvaluationCaseResult? = nil,
    directory: URL
  ) throws {
    try validateCaseName(caseName)
    let manager = FileManager.default
    let destination = directory.appendingPathComponent(caseName, isDirectory: true)
    guard !exists(destination) else { throw SyntheticArtifactError.outputExists(destination.path) }
    let staging = directory.appendingPathComponent(
      ".\(caseName)-\(UUID().uuidString)", isDirectory: true)
    do {
      try manager.createDirectory(at: directory, withIntermediateDirectories: true)
      try manager.createDirectory(at: staging, withIntermediateDirectories: false)
      try PNGCodec.encodeOpaqueRGBA8(expected, to: staging.appendingPathComponent("expected.png"))
      var plan: ReconstructionPlan?
      var actualSize: Size?
      var differenceExtent: Size?
      var failure: ReconstructionFailure?
      var unexpectedError: String?
      var unavailable: [String: String] = [:]
      let status: String
      switch outcome {
      case .reconstructed(let result):
        status = "reconstructed"
        plan = result.plan
        actualSize = Size(result.image)
        try PNGCodec.encodeOpaqueRGBA8(
          result.image, to: staging.appendingPathComponent("actual.png"))
        let width = min(expected.width, result.image.width)
        let height = min(expected.height, result.image.height)
        let expectedCrop = try crop(expected, width: width, height: height)
        let actualCrop = try crop(result.image, width: width, height: height)
        let difference = try ReconstructionEngine().differenceImage(
          preceding: CaptureAsset(id: "expected", sourceName: "expected.png", image: expectedCrop),
          following: CaptureAsset(id: "actual", sourceName: "actual.png", image: actualCrop),
          joint: JointDiagnosis(
            precedingCaptureID: "expected", followingCaptureID: "actual",
            overlapRows: height, seamRowInOverlap: 0, outputSeamRow: 0,
            normalizedMeanAbsoluteError: 0, changedPixelFraction: 0, confidence: .exact
          )
        )
        differenceExtent = Size(difference)
        try PNGCodec.encodeOpaqueRGBA8(
          difference, to: staging.appendingPathComponent("difference.png"))
        let jointsDirectory = staging.appendingPathComponent("joints", isDirectory: true)
        try manager.createDirectory(at: jointsDirectory, withIntermediateDirectories: false)
        for (index, joint) in result.plan.joints.enumerated() {
          guard let preceding = captures.first(where: { $0.id == joint.precedingCaptureID }) else {
            throw SyntheticArtifactError.missingCapture(joint.precedingCaptureID.rawValue)
          }
          guard let following = captures.first(where: { $0.id == joint.followingCaptureID }) else {
            throw SyntheticArtifactError.missingCapture(joint.followingCaptureID.rawValue)
          }
          let stem = String(format: "joint-%03d", index + 1)
          let name = "\(stem)-difference.png"
          let difference = try ReconstructionEngine().differenceImage(
            preceding: preceding, following: following, joint: joint
          )
          try PNGCodec.encodeOpaqueRGBA8(
            difference, to: jointsDirectory.appendingPathComponent(name))
          try writeJSON(
            JointManifest(diagnosis: joint, differenceFileName: name),
            to: jointsDirectory.appendingPathComponent("\(stem).json")
          )
        }
      case .failed(let error):
        status = "failed"
        failure = error
      case .unexpectedError(let description):
        status = "unexpected-error"
        unexpectedError = description
      }
      if plan == nil {
        let reason = "Reconstruction did not produce a composite or joint plan."
        unavailable = ["actual.png": reason, "difference.png": reason, "joints": reason]
      }
      try writeJSON(
        Manifest(
          caseName: caseName, status: status, assessment: assessment,
          expectedSize: Size(expected), actualSize: actualSize, differenceExtent: differenceExtent,
          unavailableArtifacts: unavailable,
          captures: captures.map {
            Capture(id: $0.id, width: $0.image.width, height: $0.image.height)
          },
          plan: plan, reconstructionFailure: failure, unexpectedError: unexpectedError
        ),
        to: staging.appendingPathComponent("manifest.json")
      )
      guard !exists(destination) else {
        throw SyntheticArtifactError.outputExists(destination.path)
      }
      try manager.moveItem(at: staging, to: destination)
    } catch {
      // Only remove this invocation's staging directory, never supplied paths.
      if exists(staging) {
        do { try manager.removeItem(at: staging) } catch let cleanupError {
          throw SyntheticArtifactError.publicationFailed(
            caseName: caseName, reason: "\(error); staging cleanup also failed: \(cleanupError)"
          )
        }
      }
      throw SyntheticArtifactError.publicationFailed(
        caseName: caseName, reason: String(describing: error))
    }
  }

  private static func exists(_ url: URL) -> Bool {
    (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
  }

  private static func crop(_ image: RasterImage, width: Int, height: Int) throws -> RasterImage {
    if image.width == width, image.height == height { return image }
    var pixels: [UInt8] = []
    pixels.reserveCapacity(width * height * RasterImage.channelsPerPixel)
    for row in 0..<height {
      let start = row * image.rowByteCount
      pixels.append(
        contentsOf: image.pixels[start..<(start + width * RasterImage.channelsPerPixel)])
    }
    return try RasterImage(width: width, height: height, pixels: pixels)
  }

  private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(value).write(to: url, options: .atomic)
  }
}
