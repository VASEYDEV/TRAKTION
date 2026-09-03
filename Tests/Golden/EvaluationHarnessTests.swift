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
    XCTAssertEqual(report.schemaVersion, 2)

    let baseline = try XCTUnwrap(report.cases.first { $0.name == "baseline" })
    XCTAssertEqual(baseline.verdict, .pass)
    XCTAssertEqual(baseline.orderPolicy, .supplied)
    XCTAssertEqual(baseline.pixelEqualToSource, true)
    XCTAssertEqual(baseline.missingRows, 0)
    XCTAssertEqual(baseline.duplicatedRows, 0)
    XCTAssertEqual(baseline.registrationErrors, [0, 0])
    XCTAssertEqual(baseline.seamEnergies, [0, 0])
    XCTAssertNil(baseline.recoveredOrder)
    XCTAssertTrue(baseline.deterministic)

    let degraded = try XCTUnwrap(report.cases.first { $0.name == "degraded" })
    XCTAssertEqual(degraded.verdict, .pass)
    XCTAssertNil(degraded.pixelEqualToSource, "near-exact fixtures skip source equality")
    for energy in try XCTUnwrap(degraded.seamEnergies) {
      XCTAssertGreaterThan(energy, 0)
      XCTAssertLessThan(energy, 0.01, "degraded seams must stay near-exact")
    }
  }

  /// Exact-ordering cases (docs/tasks/0008): shuffled and reversed exact
  /// input must recover the documentary order and reproduce the source
  /// exactly; a coverage gap and a duplicate must end in their pinned typed
  /// refusals; the exact-only boundary on near-exact captures is recorded.
  func testStandardCorpusOrderingCases() throws {
    let report = try EvaluationHarness.evaluate()

    let shuffled = try XCTUnwrap(report.cases.first { $0.name == "order-shuffled-baseline" })
    XCTAssertEqual(shuffled.orderPolicy, .exact)
    XCTAssertEqual(shuffled.verdict, .pass)
    XCTAssertEqual(shuffled.outcome, "reconstructed")
    XCTAssertEqual(shuffled.pixelEqualToSource, true)
    XCTAssertEqual(shuffled.missingRows, 0)
    XCTAssertEqual(shuffled.duplicatedRows, 0)
    XCTAssertEqual(shuffled.registrationErrors, [0, 0, 0, 0])
    XCTAssertEqual(shuffled.seamEnergies, [0, 0, 0, 0])
    XCTAssertEqual(
      shuffled.recoveredOrder,
      ["capture-001", "capture-002", "capture-003", "capture-004", "capture-005"]
    )

    let reversed = try XCTUnwrap(report.cases.first { $0.name == "order-reversed" })
    XCTAssertEqual(reversed.verdict, .pass)
    XCTAssertEqual(reversed.pixelEqualToSource, true)
    XCTAssertEqual(reversed.registrationErrors, [0, 0])
    XCTAssertEqual(reversed.recoveredOrder, ["capture-003", "capture-002", "capture-001"])

    let gap = try XCTUnwrap(report.cases.first { $0.name == "order-missing-middle" })
    XCTAssertEqual(gap.verdict, .pass)
    XCTAssertEqual(gap.outcome, "failed")
    XCTAssertEqual(gap.failureCode, "sequenceOrderNotFound")
    XCTAssertNil(gap.recoveredOrder)

    let duplicate = try XCTUnwrap(report.cases.first { $0.name == "order-duplicate-capture" })
    XCTAssertEqual(duplicate.verdict, .pass)
    XCTAssertEqual(duplicate.failureCode, "duplicateCapture")

    let degraded = try XCTUnwrap(report.cases.first { $0.name == "order-degraded-exact-only" })
    XCTAssertEqual(degraded.verdict, .pass, "the exact-only boundary is a pinned contract")
    XCTAssertEqual(degraded.failureCode, "sequenceOrderNotFound")

    let ordering = report.summary.ordering
    XCTAssertEqual(ordering.cases, 5)
    XCTAssertEqual(ordering.sequencesExpected, 3)
    XCTAssertEqual(ordering.sequencesCorrect, 2, "exact-only cannot order near-exact captures")
    XCTAssertEqual(ordering.duplicatesExpected, 1)
    XCTAssertEqual(ordering.duplicatesIdentified, 1)
    XCTAssertEqual(ordering.missingCapturesExpected, 1)
    XCTAssertEqual(ordering.missingCapturesDetected, 1)
    XCTAssertEqual(ordering.correctSequenceRate, 2.0 / 3.0)
    XCTAssertEqual(ordering.duplicateIdentificationRate, 1)
    XCTAssertEqual(ordering.missingCaptureDetectionRate, 1)
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
    let report = try EvaluationHarness.evaluate([
      EvaluationCase(name: "solo", configuration: FixtureControlConfiguration(seed: 9)),
      EvaluationCase(
        name: "solo-ordered",
        configuration: FixtureControlConfiguration(seed: 9),
        ordering: OrderingCase(permutation: [1, 0, 2], expected: .reconstruct)
      ),
    ])
    let decoded = try JSONDecoder().decode(
      EvaluationReport.self,
      from: JSONEncoder().encode(report)
    )
    XCTAssertEqual(decoded, report)
    XCTAssertNil(report.summary.ordering.duplicateIdentificationRate, "no denominator")
    XCTAssertEqual(report.summary.ordering.correctSequenceRate, 1)
  }

  func testInvalidPermutationIsRejected() {
    XCTAssertThrowsError(
      try EvaluationHarness.evaluate([
        EvaluationCase(
          name: "bad-permutation",
          configuration: FixtureControlConfiguration(seed: 9),
          ordering: OrderingCase(permutation: [0, 0, 1], expected: .reconstruct)
        ),
      ])
    ) { error in
      XCTAssertEqual(
        error as? EvaluationHarness.EvaluationCaseError,
        .invalidPermutation(caseName: "bad-permutation", permutation: [0, 0, 1], captureCount: 3)
      )
    }
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

    // Ordering: a recovered order that differs from the documentary order →
    // false-safe, even when the composite itself is plausible.
    let wrongOrder = EvaluationHarness.assess(
      name: "fabricated",
      bundle: baselineBundle,
      outcome: .reconstructed(baselineResult),
      ordering: OrderingCase(permutation: [0, 1, 2], expected: .reconstruct),
      recoveredOrder: baselineBundle.captures.reversed().map(\.id),
      deterministic: true,
      milliseconds: 0
    )
    XCTAssertEqual(wrongOrder.verdict, .falseSafe)

    // Ordering: the documentary order with correct pixels → pass, recorded
    // under the exact policy with the recovered order.
    let rightOrder = EvaluationHarness.assess(
      name: "fabricated",
      bundle: baselineBundle,
      outcome: .reconstructed(baselineResult),
      ordering: OrderingCase(permutation: [2, 0, 1], expected: .reconstruct),
      recoveredOrder: baselineBundle.captures.map(\.id),
      deterministic: true,
      milliseconds: 0
    )
    XCTAssertEqual(rightOrder.verdict, .pass)
    XCTAssertEqual(rightOrder.orderPolicy, .exact)
    XCTAssertEqual(rightOrder.recoveredOrder, baselineBundle.captures.map(\.id.rawValue))
    XCTAssertEqual(rightOrder.registrationErrors, [0, 0])

    // Ordering: a composite where the ordering expectation demands a typed
    // failure → false-safe; the wrong typed failure → wrong-failure.
    let orderedFalseSafe = EvaluationHarness.assess(
      name: "fabricated",
      bundle: baselineBundle,
      outcome: .reconstructed(baselineResult),
      ordering: OrderingCase(permutation: [0, 1, 2], expected: .fail(code: "sequenceOrderNotFound")),
      recoveredOrder: baselineBundle.captures.map(\.id),
      deterministic: true,
      milliseconds: 0
    )
    XCTAssertEqual(orderedFalseSafe.verdict, .falseSafe)
    let orderedWrongFailure = EvaluationHarness.assess(
      name: "fabricated",
      bundle: baselineBundle,
      outcome: .failed(.ambiguousSequenceOrder(candidateOrders: [["a", "b"], ["b", "a"]])),
      ordering: OrderingCase(permutation: [0, 1, 2], expected: .fail(code: "sequenceOrderNotFound")),
      deterministic: true,
      milliseconds: 0
    )
    XCTAssertEqual(orderedWrongFailure.verdict, .wrongFailure)
  }

  /// The ordering summary counts capability, not just contract conformance:
  /// a pinned refusal on a case that has a documentary order is a pass that
  /// still counts against the correct-sequence rate.
  func testOrderingSummaryCountsCapability() throws {
    let baselineBundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(seed: 31)
    )
    let pinnedRefusal = EvaluationHarness.assess(
      name: "pinned",
      bundle: baselineBundle,
      outcome: .failed(.sequenceOrderNotFound(captureIDs: baselineBundle.captures.map(\.id))),
      ordering: OrderingCase(permutation: [1, 0, 2], expected: .fail(code: "sequenceOrderNotFound")),
      deterministic: true,
      milliseconds: 0
    )
    XCTAssertEqual(pinnedRefusal.verdict, .pass)
    let summary = EvaluationHarness.orderingSummary([pinnedRefusal])
    XCTAssertEqual(summary.cases, 1)
    XCTAssertEqual(summary.sequencesExpected, 1)
    XCTAssertEqual(summary.sequencesCorrect, 0)
    XCTAssertEqual(summary.correctSequenceRate, 0)
    XCTAssertNil(summary.duplicateIdentificationRate)
    XCTAssertNil(summary.missingCaptureDetectionRate)
  }

  func testDocumentOrderOverlapsFollowGroundTruthOrigins() throws {
    let reversed = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(seed: 41, variant: .reversedOrder)
    )
    XCTAssertEqual(reversed.groundTruth.expectedOverlaps, [], "supplied-order pin is empty")
    XCTAssertEqual(EvaluationHarness.documentOrderOverlaps(reversed.groundTruth), [24, 24])

    let gap = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(seed: 42, variant: .missingMiddle)
    )
    XCTAssertEqual(
      EvaluationHarness.documentOrderOverlaps(gap.groundTruth),
      [-48],
      "a coverage gap is a negative overlap between documentary neighbors"
    )
  }
}
