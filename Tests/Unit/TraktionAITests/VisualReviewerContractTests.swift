import Foundation
import TraktionAI
import TraktionDomain
import XCTest

final class VisualReviewerContractTests: XCTestCase {
  private func makeRequest(preceding: String = "capture-001", following: String = "capture-002")
    -> VisualReviewRequest
  {
    VisualReviewRequest(
      joint: JointDiagnosis(
        precedingCaptureID: CaptureID(preceding),
        followingCaptureID: CaptureID(following),
        overlapRows: 24,
        seamRowInOverlap: 12,
        outputSeamRow: 84,
        normalizedMeanAbsoluteError: 0,
        changedPixelFraction: 0,
        confidence: .exact
      )
    )
  }

  func testDisabledReviewerAlwaysAbstains() async throws {
    let decision = try await DisabledVisualReviewer().review(makeRequest())
    XCTAssertTrue(decision.abstain)
    XCTAssertEqual(decision.action, .noChange)
    XCTAssertEqual(decision.confidence, 0)
    XCTAssertEqual(decision.reasonCode, "reviewer_disabled")
  }

  func testMockReviewerReturnsScriptAndAbstainsWhenUnscripted() async throws {
    let scripted = VisualReviewDecision(
      action: .classifyRegion,
      targetId: "capture-001/capture-002",
      classification: .stickyHeader,
      confidence: 0.9,
      abstain: false,
      reasonCode: "test_script"
    )
    let reviewer = MockVisualReviewer(decisions: ["capture-001/capture-002": scripted])

    let hit = try await reviewer.review(makeRequest())
    XCTAssertEqual(hit, scripted)

    let miss = try await reviewer.review(makeRequest(preceding: "capture-009"))
    XCTAssertTrue(miss.abstain)
    XCTAssertEqual(miss.reasonCode, "mock_unscripted_target")
  }

  func testDecisionJSONMatchesTheSchemaFieldNames() throws {
    // Field names are the contract of config/visual-review-decision.schema.json.
    let decision = VisualReviewDecision(
      action: .suspectMissingCoverage,
      targetId: "capture-002/capture-003",
      classification: .unknown,
      preferredSourceAssetId: "capture-002",
      suggestedOrder: ["capture-001", "capture-002"],
      missingCoverageSuspected: true,
      confidence: 0.5,
      abstain: false,
      reasonCode: "gap_suspected"
    )
    let data = try JSONEncoder().encode(decision)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return XCTFail("decision must encode as a JSON object")
    }
    XCTAssertEqual(
      Set(object.keys),
      [
        "action", "targetId", "classification", "preferredSourceAssetId",
        "suggestedOrder", "missingCoverageSuspected", "confidence", "abstain", "reasonCode",
      ]
    )
    XCTAssertEqual(object["action"] as? String, "suspect_missing_coverage")
    XCTAssertEqual(object["classification"] as? String, "unknown")

    let decoded = try JSONDecoder().decode(VisualReviewDecision.self, from: data)
    XCTAssertEqual(decoded, decision)
  }
}
