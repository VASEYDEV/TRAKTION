import Foundation

public enum ReconstructionAxis: String, Codable, Sendable { case vertical }
public enum JointConfidence: String, Codable, Sendable { case exact, strong, review, gap, conflict }

public struct CaptureAsset: Codable, Equatable, Sendable {
  public let id: String
  public let source: URL
  public let width: Int
  public let height: Int
  public init(id: String, source: URL, width: Int, height: Int) {
    self.id = id
    self.source = source
    self.width = width
    self.height = height
  }
}

public struct OverlapCandidate: Codable, Equatable, Sendable {
  public let rows: Int
  public let meanAbsoluteError: Double
  public let differingPixels: Int
  public init(rows: Int, meanAbsoluteError: Double, differingPixels: Int) {
    self.rows = rows
    self.meanAbsoluteError = meanAbsoluteError
    self.differingPixels = differingPixels
  }
}

public struct JointDiagnosis: Codable, Equatable, Sendable {
  public let upperCaptureID: String
  public let lowerCaptureID: String
  public let overlapRows: Int
  public let seamRowInOverlap: Int
  public let confidence: JointConfidence
  public let meanAbsoluteError: Double
  public let differingPixels: Int
  public init(
    upperCaptureID: String, lowerCaptureID: String, overlapRows: Int, seamRowInOverlap: Int,
    confidence: JointConfidence, meanAbsoluteError: Double, differingPixels: Int
  ) {
    self.upperCaptureID = upperCaptureID
    self.lowerCaptureID = lowerCaptureID
    self.overlapRows = overlapRows
    self.seamRowInOverlap = seamRowInOverlap
    self.confidence = confidence
    self.meanAbsoluteError = meanAbsoluteError
    self.differingPixels = differingPixels
  }
}

public struct ReconstructionPlan: Codable, Equatable, Sendable {
  public let axis: ReconstructionAxis
  public let captures: [CaptureAsset]
  public let joints: [JointDiagnosis]
  public let outputWidth: Int
  public let outputHeight: Int
  public init(
    axis: ReconstructionAxis, captures: [CaptureAsset], joints: [JointDiagnosis], outputWidth: Int,
    outputHeight: Int
  ) {
    self.axis = axis
    self.captures = captures
    self.joints = joints
    self.outputWidth = outputWidth
    self.outputHeight = outputHeight
  }
}

public enum ReconstructionFailure: Error, Equatable, Sendable {
  case invalidCaptureCount(actual: Int)
  case incompatibleDimensions(expectedWidth: Int, actualWidth: Int, captureID: String)
  case insufficientOverlap(upperCaptureID: String, lowerCaptureID: String)
  case duplicateCapture(captureID: String)
  case ambiguousOverlap(upperCaptureID: String, lowerCaptureID: String)
  case invalidPNG(path: String, reason: String)
  case unsupportedPNG(path: String, reason: String)
  case outputWriteFailed(path: String, reason: String)
}

extension ReconstructionFailure: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidCaptureCount(let actual): "Expected 2–10 captures; received \(actual)."
    case .incompatibleDimensions(let expected, let actual, let id):
      "Capture \(id) is \(actual) px wide; expected \(expected) px."
    case .insufficientOverlap(let upper, let lower):
      "No supported overlap between \(upper) and \(lower)."
    case .duplicateCapture(let id): "Capture \(id) duplicates its predecessor."
    case .ambiguousOverlap(let upper, let lower):
      "Multiple equally plausible overlaps exist between \(upper) and \(lower)."
    case .invalidPNG(let path, let reason): "Invalid PNG at \(path): \(reason)"
    case .unsupportedPNG(let path, let reason): "Unsupported PNG at \(path): \(reason)"
    case .outputWriteFailed(let path, let reason): "Could not write \(path): \(reason)"
    }
  }
}
