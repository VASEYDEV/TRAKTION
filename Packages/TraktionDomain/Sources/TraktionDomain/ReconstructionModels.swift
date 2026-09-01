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

/// One directed junction accepted while recovering documentary order: the
/// evidence that `followingCaptureID` continues `precedingCaptureID`.
public struct RecoveredEdge: Equatable, Codable, Sendable {
  public let precedingCaptureID: CaptureID
  public let followingCaptureID: CaptureID
  public let candidate: OverlapCandidate
  public let confidence: JointConfidence

  public init(
    precedingCaptureID: CaptureID,
    followingCaptureID: CaptureID,
    candidate: OverlapCandidate,
    confidence: JointConfidence
  ) {
    self.precedingCaptureID = precedingCaptureID
    self.followingCaptureID = followingCaptureID
    self.candidate = candidate
    self.confidence = confidence
  }
}

/// The unique acceptable documentary order recovered from an unordered
/// capture set, with per-junction evidence.
public struct RecoveredOrder: Equatable, Codable, Sendable {
  public let captureIDs: [CaptureID]
  public let edges: [RecoveredEdge]

  public init(captureIDs: [CaptureID], edges: [RecoveredEdge]) {
    self.captureIDs = captureIDs
    self.edges = edges
  }
}

public struct OrderedReconstruction: Equatable, Sendable {
  public let order: RecoveredOrder
  public let result: ReconstructionResult

  public init(order: RecoveredOrder, result: ReconstructionResult) {
    self.order = order
    self.result = result
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
  case resourceLimitExceeded(reason: String)
  case outputDimensionsOverflow
  case invalidPlan(reason: String)
  case ambiguousOrder(candidateOrders: [[CaptureID]], totalCandidates: Int)
  case missingCoverage(
    coveredCaptureIDs: [CaptureID],
    uncoveredCaptureIDs: [CaptureID]
  )
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
    case .resourceLimitExceeded: return "resourceLimitExceeded"
    case .outputDimensionsOverflow: return "outputDimensionsOverflow"
    case .invalidPlan: return "invalidPlan"
    case .ambiguousOrder: return "ambiguousOrder"
    case .missingCoverage: return "missingCoverage"
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
    case .resourceLimitExceeded(let reason):
      return "The reconstruction exceeds a configured resource limit: \(reason)."
    case .outputDimensionsOverflow:
      return "The reconstructed output dimensions exceed safe integer or memory limits."
    case .invalidPlan(let reason):
      return "The reconstruction plan is invalid: \(reason)"
    case .ambiguousOrder(let candidateOrders, let totalCandidates):
      let orders = candidateOrders
        .map { "[\($0.map(\.rawValue).joined(separator: " → "))]" }
        .joined(separator: ", ")
      return "\(totalCandidates) capture orders are acceptable; the documentary order cannot be proven. Candidates include \(orders)."
    case .missingCoverage(let covered, let uncovered):
      let coveredChain = covered.map(\.rawValue).joined(separator: " → ")
      let uncoveredList = uncovered.map(\.rawValue).joined(separator: ", ")
      return "No acceptable order covers every capture. Longest chain: [\(coveredChain)]; unconnected: \(uncoveredList)."
    }
  }
}
