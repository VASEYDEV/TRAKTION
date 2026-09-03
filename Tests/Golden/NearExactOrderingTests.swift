import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

/// Golden coverage for near-exact order recovery (docs/tasks/0009, ADR-015).
/// Recovery must reproduce the documentary order only when uniquely
/// registered near-exact evidence forms exactly one complete path; every
/// other outcome is a typed refusal and never a composite.
final class NearExactOrderingTests: XCTestCase {
  private let engine = ReconstructionEngine()

  private func degradedBundle(seed: UInt64 = 9001) throws -> FixtureControlBundle {
    try FixtureControlGenerator.generate(
      FixtureControlConfiguration(
        sourceID: "near-exact",
        seed: seed,
        variant: .degraded(maxChannelDelta: 2)
      )
    )
  }

  private func stacked(_ top: RasterImage, _ bottom: RasterImage) throws -> RasterImage {
    try RasterImage(
      width: top.width,
      height: top.height + bottom.height,
      pixels: top.pixels + bottom.pixels
    )
  }

  /// Two captures sharing both their leading and trailing bands, so each
  /// direction registers exactly one acceptable overlap: the documentary
  /// order is genuinely unprovable.
  private func symmetricPair() throws -> [CaptureAsset] {
    let bandX = try SyntheticFixtureFactory.document(width: 64, height: 40, seed: 900)
    let bandY = try SyntheticFixtureFactory.document(width: 64, height: 40, seed: 901)
    return [
      CaptureAsset(id: "sym-a", sourceName: "sym-a.png", image: try stacked(bandX, bandY)),
      CaptureAsset(id: "sym-b", sourceName: "sym-b.png", image: try stacked(bandY, bandX)),
    ]
  }

  /// Every output row must be byte-identical to the row of the capture that
  /// owns its span — pixels are preserved verbatim, never blended or invented.
  private func assertRowsComeVerbatimFromContributingCaptures(
    _ result: ReconstructionResult,
    _ capturesByID: [CaptureID: CaptureAsset],
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    for (index, placement) in result.plan.placements.enumerated() {
      let capture = try XCTUnwrap(capturesByID[placement.captureID], file: file, line: line)
      let startRow = index == 0 ? 0 : result.plan.joints[index - 1].outputSeamRow
      let endRow = index == result.plan.placements.count - 1
        ? result.plan.outputHeight
        : result.plan.joints[index].outputSeamRow
      for outputRow in startRow..<endRow {
        let sourceRow = outputRow - placement.originY
        let outputStart = outputRow * result.image.rowByteCount
        let captureStart = sourceRow * capture.image.rowByteCount
        XCTAssertEqual(
          Array(result.image.pixels[outputStart..<(outputStart + result.image.rowByteCount)]),
          Array(capture.image.pixels[captureStart..<(captureStart + capture.image.rowByteCount)]),
          "output row \(outputRow) must come verbatim from \(capture.id)",
          file: file,
          line: line
        )
      }
    }
  }

  // MARK: - Recovery of provable orders

  func testShuffledDegradedCapturesRecoverDocumentOrderVerbatim() throws {
    let bundle = try degradedBundle()
    let shuffled = [bundle.captures[1], bundle.captures[2], bundle.captures[0]]

    let result = try engine.reconstructNearExactUnordered(shuffled)

    XCTAssertEqual(
      result.plan.placements.map(\.captureID.rawValue),
      bundle.groundTruth.expectedOrder
    )
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), bundle.groundTruth.expectedOverlaps)
    XCTAssertEqual(
      result.plan.joints.map(\.confidence),
      Array(repeating: JointConfidence.strong, count: bundle.captures.count - 1)
    )
    let byID = Dictionary(uniqueKeysWithValues: bundle.captures.map { ($0.id, $0) })
    try assertRowsComeVerbatimFromContributingCaptures(result, byID)

    // Replaying through the supplied-order path means the plan and pixels are
    // exactly what supplied-order reconstruction of the same order yields.
    let supplied = try engine.reconstruct(CaptureSequence(captures: bundle.captures))
    XCTAssertEqual(result.plan, supplied.plan)
    XCTAssertEqual(result.image, supplied.image)
  }

  /// The boundary task 0009 lifts: the same near-exact input is unprovable
  /// under exact-only evidence and refuses there, typed.
  func testExactPolicyStillRefusesTheSameNearExactInput() throws {
    let bundle = try degradedBundle()
    let shuffled = [bundle.captures[1], bundle.captures[2], bundle.captures[0]]
    XCTAssertThrowsError(try engine.reconstructExactUnordered(shuffled)) { error in
      guard case .sequenceOrderNotFound = error as? ReconstructionFailure else {
        return XCTFail("expected sequenceOrderNotFound, got \(error)")
      }
    }
  }

  func testExactCapturesRecoverUnderNearExactPolicy() throws {
    let bundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(sourceID: "near-exact-exact", captureCount: 5, seed: 9002)
    )
    let shuffled = [2, 4, 0, 3, 1].map { bundle.captures[$0] }

    let result = try engine.reconstructNearExactUnordered(shuffled)
    XCTAssertEqual(
      result.plan.placements.map(\.captureID.rawValue),
      bundle.groundTruth.expectedOrder
    )
    XCTAssertEqual(result.image, bundle.source)
    XCTAssertEqual(
      result.plan.joints.map(\.confidence),
      Array(repeating: JointConfidence.exact, count: 4)
    )
  }

  func testInputPermutationDoesNotChangePlanOrPixels() throws {
    let bundle = try degradedBundle(seed: 9003)
    let first = try engine.reconstructNearExactUnordered([
      bundle.captures[2], bundle.captures[0], bundle.captures[1],
    ])
    let second = try engine.reconstructNearExactUnordered([
      bundle.captures[1], bundle.captures[2], bundle.captures[0],
    ])
    XCTAssertEqual(first.plan, second.plan)
    XCTAssertEqual(first.image, second.image)
  }

  // MARK: - Typed refusals

  func testMissingCoverageFailsWithoutProducingAResult() throws {
    let bundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(sourceID: "near-exact-gap", seed: 9004, variant: .missingMiddle)
    )
    XCTAssertThrowsError(
      try engine.reconstructNearExactUnordered([bundle.captures[1], bundle.captures[0]])
    ) { error in
      guard case .sequenceOrderNotFound(let ids) = error as? ReconstructionFailure else {
        return XCTFail("expected sequenceOrderNotFound, got \(error)")
      }
      XCTAssertEqual(ids.map(\.rawValue), ["capture-001", "capture-002"])
    }
  }

  func testSymmetricContentFailsAsAmbiguousOrder() throws {
    let captures = try symmetricPair()
    XCTAssertThrowsError(try engine.reconstructNearExactUnordered(captures)) { error in
      guard case .ambiguousSequenceOrder(let orders) = error as? ReconstructionFailure else {
        return XCTFail("expected ambiguousSequenceOrder, got \(error)")
      }
      XCTAssertEqual(
        orders.map { $0.map(\.rawValue) },
        [["sym-a", "sym-b"], ["sym-b", "sym-a"]]
      )
    }
  }

  /// Pair-level ambiguity never becomes an edge: the periodic pair is
  /// ambiguous at every forward offset (rows [4, 8, 12, 16], pinned by the
  /// supplied-order golden) and has no acceptable reverse overlap, so
  /// recovery must refuse rather than route through unprovable evidence.
  func testPairLevelAmbiguityNeverBecomesAnEdge() throws {
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(minimumOverlapRows: 4)
    )
    let captures = [
      CaptureAsset(
        id: "periodic-001",
        sourceName: "periodic-001.png",
        image: try periodicImage(uniqueTail: false)
      ),
      CaptureAsset(
        id: "periodic-002",
        sourceName: "periodic-002.png",
        image: try periodicImage(uniqueTail: true)
      ),
    ]
    XCTAssertThrowsError(try engine.reconstructNearExactUnordered(captures)) { error in
      guard case .sequenceOrderNotFound = error as? ReconstructionFailure else {
        return XCTFail("expected sequenceOrderNotFound, got \(error)")
      }
    }
    // The supplied-order path still reports the pair-level ambiguity itself.
    XCTAssertThrowsError(try engine.reconstruct(CaptureSequence(captures: captures))) { error in
      guard case .ambiguousOverlap(_, _, let rows) = error as? ReconstructionFailure else {
        return XCTFail("expected ambiguousOverlap, got \(error)")
      }
      XCTAssertEqual(rows, [4, 8, 12, 16])
    }
  }

  func testStarvedSampleBudgetFailsClosedDuringGraphConstruction() throws {
    let bundle = try degradedBundle(seed: 9005)
    let starved = ReconstructionEngine(
      settings: ReconstructionSettings(maximumSampleComparisonsPerJoint: 1)
    )
    XCTAssertThrowsError(
      try starved.reconstructNearExactUnordered([bundle.captures[2], bundle.captures[0], bundle.captures[1]])
    ) { error in
      guard case .resourceLimitExceeded = error as? ReconstructionFailure else {
        return XCTFail("expected resourceLimitExceeded, got \(error)")
      }
    }
  }

  func testOrderingBudgetFailsClosedBeforeAnyProbe() throws {
    let bundle = try degradedBundle(seed: 9006)
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(maximumOrderingComparisonPixels: 1)
    )
    XCTAssertThrowsError(try engine.reconstructNearExactUnordered(bundle.captures)) { error in
      guard case .resourceLimitExceeded(let reason) = error as? ReconstructionFailure else {
        return XCTFail("expected resourceLimitExceeded, got \(error)")
      }
      XCTAssertTrue(reason.contains("near-exact sequence ordering"))
    }
  }

  func testByteIdenticalDuplicatesStayTypedFailures() throws {
    let bundle = try degradedBundle(seed: 9007)
    let copy = CaptureAsset(id: "copy", sourceName: "copy.png", image: bundle.captures[0].image)
    XCTAssertThrowsError(
      try engine.reconstructNearExactUnordered([bundle.captures[0], copy, bundle.captures[1]])
    ) { error in
      guard case .duplicateCapture = error as? ReconstructionFailure else {
        return XCTFail("expected duplicateCapture, got \(error)")
      }
    }
  }

  func testCaptureCountAndAxisBoundsApply() throws {
    let bundle = try degradedBundle(seed: 9008)
    XCTAssertThrowsError(try engine.reconstructNearExactUnordered([bundle.captures[0]])) {
      XCTAssertEqual(
        $0 as? ReconstructionFailure,
        .captureCountOutOfRange(actual: 1, allowed: 2...10)
      )
    }
    XCTAssertThrowsError(
      try engine.reconstructNearExactUnordered(bundle.captures, axis: .horizontal)
    ) {
      XCTAssertEqual($0 as? ReconstructionFailure, .unsupportedAxis(.horizontal))
    }
  }

  private func periodicImage(uniqueTail: Bool) throws -> RasterImage {
    let width = 12
    let height = 20
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
      let rowValue: UInt8
      if uniqueTail, y >= 16 {
        rowValue = UInt8(160 + y)
      } else {
        rowValue = UInt8((y % 4) * 40)
      }
      for x in 0..<width {
        let offset = ((y * width) + x) * 4
        pixels[offset] = rowValue
        pixels[offset + 1] = rowValue
        pixels[offset + 2] = rowValue
        pixels[offset + 3] = 255
      }
    }
    return try RasterImage(width: width, height: height, pixels: pixels)
  }
}
