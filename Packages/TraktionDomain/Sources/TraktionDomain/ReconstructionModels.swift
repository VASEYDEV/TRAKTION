public enum JointConfidence: String, Codable, Sendable {
  case exact
  case strong
  case review
  case gap
  case conflict
}

public struct OverlapCandidate: Equatable, Codable, Sendable {
  public let overlapRows: Int
  public let normalizedMeanAbsoluteError: Double
  public let changedPixelFraction: Double

  public init(
    overlapRows: Int,
    normalizedMeanAbsoluteError: Double,
    changedPixelFraction: Double
  ) {
    self.overlapRows = overlapRows
    self.normalizedMeanAbsoluteError = normalizedMeanAbsoluteError
    self.changedPixelFraction = changedPixelFraction
  }
}

public struct CapturePlacement: Equatable, Codable, Sendable {
  public let captureID: CaptureID
  public let originY: Int
  public let width: Int
  public let height: Int

  public init(captureID: CaptureID, originY: Int, width: Int, height: Int) {
    self.captureID = captureID
    self.originY = originY
    self.width = width
    self.height = height
  }
}

public struct JointDiagnosis: Equatable, Codable, Sendable {
  public let precedingCaptureID: CaptureID
  public let followingCaptureID: CaptureID
  public let overlapRows: Int
  public let seamRowInOverlap: Int
  public let outputSeamRow: Int
  public let normalizedMeanAbsoluteError: Double
  public let changedPixelFraction: Double
  public let confidence: JointConfidence

  public init(
    precedingCaptureID: CaptureID,
    followingCaptureID: CaptureID,
    overlapRows: Int,
    seamRowInOverlap: Int,
    outputSeamRow: Int,
    normalizedMeanAbsoluteError: Double,
    changedPixelFraction: Double,
    confidence: JointConfidence
  ) {
    self.precedingCaptureID = precedingCaptureID
    self.followingCaptureID = followingCaptureID
    self.overlapRows = overlapRows
    self.seamRowInOverlap = seamRowInOverlap
    self.outputSeamRow = outputSeamRow
    self.normalizedMeanAbsoluteError = normalizedMeanAbsoluteError
    self.changedPixelFraction = changedPixelFraction
    self.confidence = confidence
  }
}

public struct ReconstructionPlan: Equatable, Codable, Sendable {
  public let axis: ReconstructionAxis
  public let outputWidth: Int
  public let outputHeight: Int
  public let placements: [CapturePlacement]
  public let joints: [JointDiagnosis]

  public init(
    axis: ReconstructionAxis,
    outputWidth: Int,
    outputHeight: Int,
    placements: [CapturePlacement],
    joints: [JointDiagnosis]
  ) {
    self.axis = axis
    self.outputWidth = outputWidth
    self.outputHeight = outputHeight
    self.placements = placements
    self.joints = joints
  }
}

public struct ReconstructionResult: Equatable, Sendable {
  public let plan: ReconstructionPlan
  public let image: RasterImage

  public init(plan: ReconstructionPlan, image: RasterImage) {
    self.plan = plan
    self.image = image
  }
}

public enum ReconstructionFailure: Error, Equatable, Codable, Sendable {
  case unsupportedAxis(ReconstructionAxis)
  case captureCountOutOfRange(actual: Int, allowed: ClosedRange<Int>)
  case incompatibleDimensions(
    expectedWidth: Int,
    actualWidth: Int,
    captureID: CaptureID
  )
  case duplicateCapture(preceding: CaptureID, following: CaptureID)
  case insufficientOverlap(
    preceding: CaptureID,
    following: CaptureID,
    minimumRows: Int
  )
  case ambiguousOverlap(
    preceding: CaptureID,
    following: CaptureID,
    candidateRows: [Int]
  )
  case sequenceOrderNotFound(captureIDs: [CaptureID])
  case ambiguousSequenceOrder(candidateOrders: [[CaptureID]])
  case resourceLimitExceeded(reason: String)
  case outputDimensionsOverflow
  case invalidPlan(reason: String)
}

extension ReconstructionFailure {
  /// Stable machine-readable identifier for this failure case, shared by
  /// manifests and fixture ground truth. Values are a wire contract; never
  /// rename them.
  public var code: String {
    switch self {
    case .unsupportedAxis: return "unsupportedAxis"
    case .captureCountOutOfRange: return "captureCountOutOfRange"
    case .incompatibleDimensions: return "incompatibleDimensions"
    case .duplicateCapture: return "duplicateCapture"
    case .insufficientOverlap: return "insufficientOverlap"
    case .ambiguousOverlap: return "ambiguousOverlap"
    case .sequenceOrderNotFound: return "sequenceOrderNotFound"
    case .ambiguousSequenceOrder: return "ambiguousSequenceOrder"
    case .resourceLimitExceeded: return "resourceLimitExceeded"
    case .outputDimensionsOverflow: return "outputDimensionsOverflow"
    case .invalidPlan: return "invalidPlan"
    }
  }
}

extension ReconstructionFailure: CustomStringConvertible {
  public var description: String {
    switch self {
    case .unsupportedAxis(let axis):
      return "Unsupported reconstruction axis: \(axis.rawValue)."
    case .captureCountOutOfRange(let actual, let allowed):
      return "Expected \(allowed.lowerBound)-\(allowed.upperBound) captures; received \(actual)."
    case .incompatibleDimensions(let expected, let actual, let captureID):
      return "Capture \(captureID) is \(actual) px wide; expected \(expected) px."
    case .duplicateCapture(let preceding, let following):
      return "Captures \(preceding) and \(following) are byte-identical duplicates."
    case .insufficientOverlap(let preceding, let following, let minimumRows):
      return "No valid overlap of at least \(minimumRows) rows exists between \(preceding) and \(following)."
    case .ambiguousOverlap(let preceding, let following, let candidateRows):
      return "Overlap between \(preceding) and \(following) is ambiguous at rows \(candidateRows)."
    case .sequenceOrderNotFound(let captureIDs):
      return "No complete exact-overlap order exists for captures \(captureIDs)."
    case .ambiguousSequenceOrder(let candidateOrders):
      return "Capture order is ambiguous; valid orders: \(candidateOrders)."
    case .resourceLimitExceeded(let reason):
      return "The reconstruction exceeds a configured resource limit: \(reason)."
    case .outputDimensionsOverflow:
      return "The reconstructed output dimensions exceed safe integer or memory limits."
    case .invalidPlan(let reason):
      return "The reconstruction plan is invalid: \(reason)"
    }
  }
}
