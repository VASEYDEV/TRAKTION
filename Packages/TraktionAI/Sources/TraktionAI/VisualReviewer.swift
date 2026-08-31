import TraktionDomain

public struct VisualReviewRequest: Equatable, Sendable {
  public let joint: JointDiagnosis

  public init(joint: JointDiagnosis) {
    self.joint = joint
  }
}

public enum VisualReviewRecommendation: Equatable, Sendable {
  case abstain(reason: String)
}

public protocol VisualReviewer: Sendable {
  func review(_ request: VisualReviewRequest) async -> VisualReviewRecommendation
}

public struct DisabledVisualReviewer: VisualReviewer, Sendable {
  public init() {}

  public func review(_ request: VisualReviewRequest) async -> VisualReviewRecommendation {
    _ = request
    return .abstain(reason: "Semantic review is disabled for Milestone 1.")
  }
}
