import FixtureForgeKit
import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision
import XCTest

@testable import TraktionLabEvaluation

final class NondeterminismArtifactTests: XCTestCase {
  private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "traktion-run-artifacts-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    addTeardownBlock { try FileManager.default.removeItem(at: url) }
    return url
  }

  private func fixture() throws -> (FixtureControlBundle, ReconstructionResult) {
    let bundle = try FixtureControlGenerator.generate(FixtureControlConfiguration(seed: 12021))
    let result = try ReconstructionEngine().reconstruct(CaptureSequence(captures: bundle.captures))
    return (bundle, result)
  }

  private func manifest(_ directory: URL) throws -> [String: Any] {
    try XCTUnwrap(
      JSONSerialization.jsonObject(
        with: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        as? [String: Any]
    )
  }

  func testPixelDisagreementRetainsBothRastersAndTheirOwnAssessments() throws {
    let directory = try directory()
    let (bundle, result) = try fixture()
    var pixels = result.image.pixels
    pixels[0] ^= 127
    let changedImage = try RasterImage(
      width: result.image.width, height: result.image.height, pixels: pixels)
    let changedResult = ReconstructionResult(plan: result.plan, image: changedImage)

    let assessment = try EvaluationHarness.assessRuns(
      name: "pixel-disagreement", bundle: bundle, captures: bundle.captures,
      first: .init(outcome: .reconstructed(result), recoveredOrder: nil, milliseconds: 11),
      second: .init(outcome: .reconstructed(changedResult), recoveredOrder: nil, milliseconds: 22),
      artifacts: EvaluationArtifactOptions(directory: directory)
    )
    XCTAssertEqual(assessment.verdict, .pass, "The report retains the first run's verdict.")
    XCTAssertFalse(assessment.deterministic)
    XCTAssertFalse(EvaluationHarness.summarize([assessment]).isAcceptable)
    let caseDirectory = directory.appendingPathComponent("pixel-disagreement")
    let caseManifest = try manifest(caseDirectory)
    XCTAssertEqual(caseManifest["status"] as? String, "nondeterministic")
    XCTAssertEqual(caseManifest["caseName"] as? String, "pixel-disagreement")
    XCTAssertEqual(caseManifest["runDirectories"] as? [String], ["run-1", "run-2"])
    for (index, image) in [result.image, changedImage].enumerated() {
      let runDirectory = caseDirectory.appendingPathComponent("run-\(index + 1)")
      XCTAssertEqual(
        try PNGCodec.decodeOpaqueRGBA8(from: runDirectory.appendingPathComponent("actual.png")),
        image
      )
      XCTAssertEqual(
        try PNGCodec.decodeOpaqueRGBA8(from: runDirectory.appendingPathComponent("expected.png")),
        bundle.source
      )
      let record = try manifest(runDirectory)
      let runAssessment = try XCTUnwrap(record["assessment"] as? [String: Any])
      XCTAssertEqual(record["caseName"] as? String, "run-\(index + 1)")
      XCTAssertEqual(runAssessment["name"] as? String, "pixel-disagreement")
      XCTAssertEqual(runAssessment["verdict"] as? String, index == 0 ? "pass" : "false-safe")
      XCTAssertEqual(runAssessment["milliseconds"] as? Int, index == 0 ? 11 : 22)
      XCTAssertEqual(runAssessment["deterministic"] as? Bool, false)
      XCTAssertTrue(
        FileManager.default.fileExists(
          atPath: runDirectory.appendingPathComponent("joints/joint-001-difference.png").path))
      let difference = try PNGCodec.decodeOpaqueRGBA8(
        from: runDirectory.appendingPathComponent("difference.png"))
      XCTAssertEqual(
        difference.pixels[0], UInt8(abs(Int(bundle.source.pixels[0]) - Int(image.pixels[0]))))
      XCTAssertEqual(difference.pixels[3], 255)
    }
  }

  func testRecoveredOrderDisagreementSurvivesEvenWhenPlansAndPixelsAreIdentical() throws {
    let directory = try directory()
    let (bundle, result) = try fixture()
    let firstOrder = bundle.captures.map(\.id)
    let secondOrder = Array(firstOrder.reversed())
    let assessment = try EvaluationHarness.assessRuns(
      name: "order-disagreement", bundle: bundle, captures: bundle.captures,
      ordering: OrderingCase(permutation: [0, 1, 2], expected: .reconstruct),
      first: .init(outcome: .reconstructed(result), recoveredOrder: firstOrder, milliseconds: 1),
      second: .init(outcome: .reconstructed(result), recoveredOrder: secondOrder, milliseconds: 2),
      artifacts: EvaluationArtifactOptions(directory: directory)
    )
    XCTAssertEqual(assessment.verdict, .pass)
    XCTAssertFalse(assessment.deterministic)
    for (index, order) in [firstOrder, secondOrder].enumerated() {
      let runDirectory = directory.appendingPathComponent("order-disagreement/run-\(index + 1)")
      let record = try manifest(runDirectory)
      let runAssessment = try XCTUnwrap(record["assessment"] as? [String: Any])
      XCTAssertEqual(runAssessment["recoveredOrder"] as? [String], order.map(\.rawValue))
      XCTAssertEqual(runAssessment["verdict"] as? String, index == 0 ? "pass" : "false-safe")
      XCTAssertEqual(
        try PNGCodec.decodeOpaqueRGBA8(from: runDirectory.appendingPathComponent("actual.png")),
        result.image
      )
    }
  }

  func testReconstructionAndRefusalKeepCorrectEvidenceInEitherRunOrder() throws {
    let directory = try directory()
    let (bundle, result) = try fixture()
    let failure = ReconstructionFailure.unsupportedAxis(.horizontal)
    for failureFirst in [true, false] {
      let caseName = failureFirst ? "failure-first" : "failure-second"
      let success = EvaluationHarness.ObservedRun(
        outcome: .reconstructed(result), recoveredOrder: nil, milliseconds: 1)
      let refusal = EvaluationHarness.ObservedRun(
        outcome: .failed(failure), recoveredOrder: nil, milliseconds: 2)
      let assessment = try EvaluationHarness.assessRuns(
        name: caseName, bundle: bundle, captures: bundle.captures,
        first: failureFirst ? refusal : success, second: failureFirst ? success : refusal,
        artifacts: EvaluationArtifactOptions(directory: directory)
      )
      XCTAssertFalse(assessment.deterministic)
      XCTAssertEqual(assessment.verdict, failureFirst ? .falseWarning : .pass)
      for ordinal in [1, 2] {
        let isRefusal = (ordinal == 1) == failureFirst
        let runDirectory = directory.appendingPathComponent("\(caseName)/run-\(ordinal)")
        let record = try manifest(runDirectory)
        XCTAssertEqual(record["status"] as? String, isRefusal ? "failed" : "reconstructed")
        let runAssessment = try XCTUnwrap(record["assessment"] as? [String: Any])
        XCTAssertEqual(runAssessment["verdict"] as? String, isRefusal ? "false-warning" : "pass")
        XCTAssertEqual(
          FileManager.default.fileExists(
            atPath: runDirectory.appendingPathComponent("actual.png").path), !isRefusal)
        XCTAssertEqual(
          FileManager.default.fileExists(
            atPath: runDirectory.appendingPathComponent("difference.png").path), !isRefusal)
        XCTAssertEqual(record["plan"] == nil, isRefusal)
        XCTAssertEqual(
          (record["unavailableArtifacts"] as? [String: String])?.count, isRefusal ? 3 : 0)
        if isRefusal {
          let error = try XCTUnwrap(record["reconstructionFailure"])
          XCTAssertEqual(
            try JSONDecoder().decode(
              ReconstructionFailure.self, from: JSONSerialization.data(withJSONObject: error)),
            failure
          )
        }
      }
    }
  }

  func testSecondRunPublicationFailureRemovesWholeCaseAndPreservesExistingFiles() throws {
    let directory = try directory()
    let sentinel = directory.appendingPathComponent("sentinel.txt")
    try Data("preserve".utf8).write(to: sentinel)
    let (bundle, result) = try fixture()
    let badPlan = ReconstructionPlan(
      axis: result.plan.axis, outputWidth: result.plan.outputWidth,
      outputHeight: result.plan.outputHeight, placements: result.plan.placements,
      joints: result.plan.joints.map {
        JointDiagnosis(
          precedingCaptureID: "missing-capture", followingCaptureID: $0.followingCaptureID,
          overlapRows: $0.overlapRows, seamRowInOverlap: $0.seamRowInOverlap,
          outputSeamRow: $0.outputSeamRow,
          normalizedMeanAbsoluteError: $0.normalizedMeanAbsoluteError,
          changedPixelFraction: $0.changedPixelFraction, confidence: $0.confidence
        )
      }
    )
    XCTAssertThrowsError(
      try EvaluationHarness.assessRuns(
        name: "late-error", bundle: bundle, captures: bundle.captures,
        first: .init(outcome: .reconstructed(result), recoveredOrder: nil, milliseconds: 1),
        second: .init(
          outcome: .reconstructed(ReconstructionResult(plan: badPlan, image: result.image)),
          recoveredOrder: nil, milliseconds: 2),
        artifacts: EvaluationArtifactOptions(directory: directory)
      ))
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: directory.path), ["sentinel.txt"])
    XCTAssertEqual(try Data(contentsOf: sentinel), Data("preserve".utf8))
  }
}
