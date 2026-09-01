import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

@testable import TraktionLabEvaluation

final class EvaluationHarnessTests: XCTestCase {
  func testStandardCorpusIsAcceptable() throws {
    let report = try EvaluationHarness.evaluate()
    XCTAssertTrue(report.summary.isAcceptable, "\(report.summary)")
    XCTAssertEqual(report.summary.cases, report.cases.count)
    XCTAssertEqual(report.summary.pass, report.cases.count)

    let baseline = try XCTUnwrap(report.cases.first { $0.name == "baseline" })
    XCTAssertEqual(baseline.verdict, .pass)
    XCTAssertEqual(baseline.pixelEqualToSource, true)
    XCTAssertEqual(baseline.missingRows, 0)
    XCTAssertEqual(baseline.duplicatedRows, 0)
    XCTAssertEqual(baseline.registrationErrors, [0, 0])
    XCTAssertEqual(baseline.seamEnergies, [0, 0])
    XCTAssertTrue(baseline.deterministic)

    let degraded = try XCTUnwrap(report.cases.first { $0.name == "degraded" })
    XCTAssertEqual(degraded.verdict, .pass)
    XCTAssertNil(degraded.pixelEqualToSource, "near-exact fixtures skip source equality")
    for energy in try XCTUnwrap(degraded.seamEnergies) {
      XCTAssertGreaterThan(energy, 0)
      XCTAssertLessThan(energy, 0.01, "degraded seams must stay near-exact")
    }
  }

  func testReportIsDeterministicAsideFromTiming() throws {
    var first = try EvaluationHarness.evaluate()
    var second = try EvaluationHarness.evaluate()
    for index in first.cases.indices {
      first.cases[index].milliseconds = 0
      second.cases[index].milliseconds = 0
    }
    XCTAssertEqual(first, second)
  }

  func testReportRoundTripsThroughCodable() throws {
    let report = try EvaluationHarness.evaluate(
      [EvaluationCase(name: "solo", configuration: FixtureControlConfiguration(seed: 9))]
    )
    let decoded = try JSONDecoder().decode(
      EvaluationReport.self,
      from: JSONEncoder().encode(report)
    )
    XCTAssertEqual(decoded, report)
  }

  /// The gate must be able to fail: fabricated outcome/expectation mismatches
  /// classify as the right verdicts.
  func testVerdictLogicClassifiesMismatches() throws {
    let baselineBundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(seed: 21)
    )
    let duplicateBundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(seed: 22, variant: .duplicateCapture)
    )
    let baselineResult = try ReconstructionEngine().reconstruct(
      CaptureSequence(captures: baselineBundle.captures)
    )

    // A composite where ground truth demands a typed failure → false-safe.
    let falseSafe = EvaluationHarness.assess(
      name: "fabricated",
      bundle: duplicateBundle,
      outcome: .reconstructed(baselineResult),
      deterministic: true,
      milliseconds: 0
    )
    XCTAssertEqual(falseSafe.verdict, .falseSafe)

    // A failure where ground truth says reconstructable → false-warning.
    let falseWarning = EvaluationHarness.assess(
      name: "fabricated",
      bundle: baselineBundle,
      outcome: .failed(.ambiguousOverlap(preceding: "a", following: "b", candidateRows: [8])),
      deterministic: true,
      milliseconds: 0
    )
    XCTAssertEqual(falseWarning.verdict, .falseWarning)

    // The required failure with a different code → wrong-failure.
    let wrongFailure = EvaluationHarness.assess(
      name: "fabricated",
      bundle: duplicateBundle,
      outcome: .failed(
        .insufficientOverlap(preceding: "a", following: "b", minimumRows: 8)
      ),
      deterministic: true,
      milliseconds: 0
    )
    XCTAssertEqual(wrongFailure.verdict, .wrongFailure)

    // A misregistered composite on a reconstructable fixture → false-safe.
    let plan = baselineResult.plan
    let fabricatedPlan = ReconstructionPlan(
      axis: plan.axis,
      outputWidth: plan.outputWidth,
      outputHeight: plan.outputHeight,
      placements: plan.placements,
      joints: plan.joints.map { joint in
        JointDiagnosis(
          precedingCaptureID: joint.precedingCaptureID,
          followingCaptureID: joint.followingCaptureID,
          overlapRows: joint.overlapRows + 3,
          seamRowInOverlap: joint.seamRowInOverlap,
          outputSeamRow: joint.outputSeamRow,
          normalizedMeanAbsoluteError: joint.normalizedMeanAbsoluteError,
          changedPixelFraction: joint.changedPixelFraction,
          confidence: joint.confidence
        )
      }
    )
    let misregistered = EvaluationHarness.assess(
      name: "fabricated",
      bundle: baselineBundle,
      outcome: .reconstructed(
        ReconstructionResult(plan: fabricatedPlan, image: baselineResult.image)
      ),
      deterministic: true,
      milliseconds: 0
    )
    XCTAssertEqual(misregistered.verdict, .falseSafe)
  }
}
