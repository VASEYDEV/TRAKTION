import Foundation
import Testing
import TraktionAI

@Suite("VisualReviewer contract")
struct VisualReviewerTests {
    @Test("Disabled reviewer always abstains — core must function without AI")
    func disabledAbstains() async throws {
        let reviewer = DisabledVisualReviewer()
        let decision = try await reviewer.review(
            VisualReviewRequest(targetID: "joint-1", evidenceSummary: "ambiguous seam")
        )
        #expect(decision.abstain)
        #expect(decision.action == .noChange)
        #expect(decision.confidence == 0)
    }

    @Test("Mock reviewer returns scripted decisions and abstains when unscripted")
    func mockScripted() async throws {
        let scripted = VisualReviewDecision(
            action: .classifyRegion,
            targetId: "joint-2",
            classification: .stickyHeader,
            confidence: 0.9,
            abstain: false,
            reasonCode: "test_script"
        )
        let reviewer = MockVisualReviewer(decisions: ["joint-2": scripted])

        let hit = try await reviewer.review(VisualReviewRequest(targetID: "joint-2", evidenceSummary: ""))
        #expect(hit == scripted)

        let miss = try await reviewer.review(VisualReviewRequest(targetID: "joint-9", evidenceSummary: ""))
        #expect(miss.abstain)
    }

    @Test("Decision JSON uses the field names of config/visual-review-decision.schema.json")
    func schemaFieldNames() throws {
        let decision = VisualReviewDecision(
            action: .suspectMissingCoverage,
            targetId: "joint-3",
            classification: .unknown,
            preferredSourceAssetId: "capture-001",
            suggestedOrder: ["capture-001", "capture-002"],
            missingCoverageSuspected: true,
            confidence: 0.5,
            abstain: false,
            reasonCode: "gap_suspected"
        )
        let data = try JSONEncoder().encode(decision)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == [
            "action", "targetId", "classification", "preferredSourceAssetId",
            "suggestedOrder", "missingCoverageSuspected", "confidence", "abstain", "reasonCode",
        ])
        #expect(object["action"] as? String == "suspect_missing_coverage")
        #expect(object["classification"] as? String == "unknown")
    }
}
