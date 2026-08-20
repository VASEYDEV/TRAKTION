import TraktionDomain

public struct VisualReviewRequest: Equatable, Sendable {
  public let joint: JointDiagnosis
  public init(joint: JointDiagnosis) { self.joint = joint }
}
public enum VisualReviewRecommendation: Equatable, Sendable {
  case abstain
  case requestManualReview(reason: String)
}
public protocol VisualReviewer: Sendable {
  func review(_ request: VisualReviewRequest) async throws -> VisualReviewRecommendation
}
public struct DisabledVisualReviewer: VisualReviewer {
  public init() {}
  public func review(_ request: VisualReviewRequest) async throws -> VisualReviewRecommendation {
    .abstain
  }
}
