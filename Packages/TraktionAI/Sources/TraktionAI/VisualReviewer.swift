import TraktionDomain

// Provider-neutral semantic review contract. TraktionAI holds protocol and
// adapters only; no provider SDK, no pixel authority. Decision fields mirror
// `config/visual-review-decision.schema.json`, and every decision is a
// recommendation that deterministic validation must accept before it can
// change output behavior (docs/ARCHITECTURE.md architectural rule).

public struct VisualReviewRequest: Equatable, Sendable {
  public let joint: JointDiagnosis

  public init(joint: JointDiagnosis) {
    self.joint = joint
  }

  /// Stable identifier for the joint under review.
  public var targetID: String {
    "\(joint.precedingCaptureID)/\(joint.followingCaptureID)"
  }
}

public enum VisualReviewAction: String, Codable, Equatable, Sendable {
  case noChange = "no_change"
  case suggestReorder = "suggest_reorder"
  case classifyRegion = "classify_region"
  case preferSource = "prefer_source"
  case suspectMissingCoverage = "suspect_missing_coverage"
  case manualReview = "manual_review"
}

public enum RegionClassification: String, Codable, Equatable, Sendable {
  case stickyHeader = "sticky_header"
  case stickyFooter = "sticky_footer"
  case floatingControl = "floating_control"
  case transientContent = "transient_content"
  case documentContent = "document_content"
  case unknown
}

public struct VisualReviewDecision: Codable, Equatable, Sendable {
  public let action: VisualReviewAction
  public let targetId: String?
  public let classification: RegionClassification?
  public let preferredSourceAssetId: String?
  public let suggestedOrder: [String]?
  public let missingCoverageSuspected: Bool
  public let confidence: Double
  public let abstain: Bool
  public let reasonCode: String

  public init(
    action: VisualReviewAction,
    targetId: String? = nil,
    classification: RegionClassification? = nil,
    preferredSourceAssetId: String? = nil,
    suggestedOrder: [String]? = nil,
    missingCoverageSuspected: Bool = false,
    confidence: Double,
    abstain: Bool,
    reasonCode: String
  ) {
    self.action = action
    self.targetId = targetId
    self.classification = classification
    self.preferredSourceAssetId = preferredSourceAssetId
    self.suggestedOrder = suggestedOrder
    self.missingCoverageSuspected = missingCoverageSuspected
    self.confidence = confidence
    self.abstain = abstain
    self.reasonCode = reasonCode
  }

  public static func abstaining(reasonCode: String) -> VisualReviewDecision {
    VisualReviewDecision(
      action: .noChange,
      confidence: 0,
      abstain: true,
      reasonCode: reasonCode
    )
  }
}

/// At most one active implementation exists in production
/// (docs/adr/ADR-003-single-runtime-reviewer.md).
public protocol VisualReviewer: Sendable {
  func review(_ request: VisualReviewRequest) async throws -> VisualReviewDecision
}

/// Default reviewer: always abstains. Core reconstruction must function with
/// this implementation alone (offline invariant).
public struct DisabledVisualReviewer: VisualReviewer {
  public init() {}

  public func review(_ request: VisualReviewRequest) async throws -> VisualReviewDecision {
    .abstaining(reasonCode: "reviewer_disabled")
  }
}

/// Test reviewer returning scripted decisions keyed by request target ID.
public struct MockVisualReviewer: VisualReviewer {
  private let decisions: [String: VisualReviewDecision]

  public init(decisions: [String: VisualReviewDecision]) {
    self.decisions = decisions
  }

  public func review(_ request: VisualReviewRequest) async throws -> VisualReviewDecision {
    decisions[request.targetID] ?? .abstaining(reasonCode: "mock_unscripted_target")
  }
}
