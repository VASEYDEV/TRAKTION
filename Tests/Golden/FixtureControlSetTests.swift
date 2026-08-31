import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

/// Golden coverage for the prompt-02 control set (docs/tasks/0003). Every
/// adversarial variant must end in the typed failure its ground truth pins;
/// every positive control must reconstruct exactly as recorded. These tests
/// are the proof that no control-set case silently corrupts documentary
/// content.
final class FixtureControlSetTests: XCTestCase {
  private let engine = ReconstructionEngine()

  private func bundle(
    _ variant: FixtureVariant,
    seed: UInt64 = 77,
    axis: ReconstructionAxis = .vertical,
    overlap: Int = 24
  ) throws -> FixtureControlBundle {
    try FixtureControlGenerator.generate(
      FixtureControlConfiguration(
        sourceID: variant.name,
        axis: axis,
        overlapLength: overlap,
        seed: seed,
        variant: variant
      )
    )
  }

  private func assertFailsAsPinned(
    _ variant: FixtureVariant,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let bundle = try bundle(variant)
    let expectedCode = try XCTUnwrap(
      bundle.groundTruth.expectedFailureCode,
      "ground truth for \(variant.name) must pin a failure code",
      file: file,
      line: line
    )
    XCTAssertThrowsError(
      try engine.reconstruct(CaptureSequence(captures: bundle.captures)),
      "\(variant.name) must not produce a composite",
      file: file,
      line: line
    ) { error in
      guard let failure = error as? ReconstructionFailure else {
        return XCTFail("\(variant.name): expected ReconstructionFailure, got \(error)", file: file, line: line)
      }
      XCTAssertEqual(failure.code, expectedCode, "\(variant.name)", file: file, line: line)
    }
  }

  // MARK: - Determinism and ground truth

  func testGenerationIsDeterministic() throws {
    for variant: FixtureVariant in [.baseline, .degraded(maxChannelDelta: 2), .scrollbar(width: 4)] {
      let first = try bundle(variant)
      let second = try bundle(variant)
      XCTAssertEqual(first.captures, second.captures, variant.name)
      XCTAssertEqual(first.groundTruth, second.groundTruth, variant.name)
      XCTAssertEqual(first.source, second.source, variant.name)
    }
  }

  func testGroundTruthRoundTripsThroughCodable() throws {
    let truth = try bundle(.duplicateCapture).groundTruth
    let encoded = try JSONEncoder().encode(truth)
    let decoded = try JSONDecoder().decode(FixtureGroundTruth.self, from: encoded)
    XCTAssertEqual(decoded, truth)
  }

  func testDifferentSeedsChangeTheFingerprint() throws {
    let first = try bundle(.baseline, seed: 1).groundTruth.sourcePixelFingerprint
    let second = try bundle(.baseline, seed: 2).groundTruth.sourcePixelFingerprint
    XCTAssertNotEqual(first, second)
    XCTAssertTrue(first.hasPrefix("fnv1a64:"))
  }

  // MARK: - Positive controls

  func testBaselineReconstructsExactly() throws {
    let bundle = try bundle(.baseline)
    let result = try engine.reconstruct(CaptureSequence(captures: bundle.captures))
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), bundle.groundTruth.expectedOverlaps)
    XCTAssertEqual(result.image, bundle.source)
  }

  func testOnePixelOffsetReconstructsWithJitteredOverlaps() throws {
    let bundle = try bundle(.onePixelOffset)
    let result = try engine.reconstruct(CaptureSequence(captures: bundle.captures))
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), bundle.groundTruth.expectedOverlaps)
    XCTAssertNotEqual(
      Set(result.plan.joints.map(\.overlapRows)).count,
      0,
      "jitter must vary at least one overlap"
    )
    XCTAssertEqual(result.image, bundle.source)
  }

  /// Every output row must be byte-identical to the row of the capture that
  /// owns its span — pixels are preserved verbatim, never blended or invented.
  private func assertRowsComeVerbatimFromContributingCaptures(
    _ result: ReconstructionResult,
    _ bundle: FixtureControlBundle,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    for (index, capture) in bundle.captures.enumerated() {
      let placement = result.plan.placements[index]
      let startRow = index == 0 ? 0 : result.plan.joints[index - 1].outputSeamRow
      let endRow = index == bundle.captures.count - 1
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

  func testDegradedReconstructsNearExactFromContributingCaptures() throws {
    let bundle = try bundle(.degraded(maxChannelDelta: 2))
    let result = try engine.reconstruct(CaptureSequence(captures: bundle.captures))
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), bundle.groundTruth.expectedOverlaps)
    XCTAssertEqual(
      result.plan.joints.map(\.confidence),
      Array(repeating: JointConfidence.strong, count: bundle.captures.count - 1)
    )
    assertRowsComeVerbatimFromContributingCaptures(result, bundle)
  }

  func testScrollbarReconstructsFaithfullyWithArtifacts() throws {
    // Empirically pinned (docs/tasks/0003): the moving thumb stays below the
    // acceptance thresholds, the unique true overlap wins, and the composite
    // carries the scrollbar pixels of whichever capture owns each span.
    // Faithful stitching of what the captures contain, not corruption;
    // scrollbar handling proper is Milestone 4.
    let bundle = try bundle(.scrollbar(width: 4))
    XCTAssertEqual(bundle.groundTruth.expectedStatus, "reconstructable-with-scrollbar-artifacts")
    let result = try engine.reconstruct(CaptureSequence(captures: bundle.captures))
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), bundle.groundTruth.expectedOverlaps)
    assertRowsComeVerbatimFromContributingCaptures(result, bundle)
  }

  func testOverlapSweepAcrossTenToEightyPercent() throws {
    for percent in [10, 25, 50, 66, 80] {
      let overlap = max(10, 96 * percent / 100)
      let bundle = try bundle(.baseline, seed: UInt64(100 + percent), overlap: overlap)
      let result = try engine.reconstruct(CaptureSequence(captures: bundle.captures))
      XCTAssertEqual(
        result.plan.joints.map(\.overlapRows),
        bundle.groundTruth.expectedOverlaps,
        "overlap \(percent)%"
      )
      XCTAssertEqual(result.image, bundle.source, "overlap \(percent)%")
    }
  }

  // MARK: - Adversarial variants: typed failure, never silent corruption

  func testDuplicateCaptureFailsTyped() throws {
    try assertFailsAsPinned(.duplicateCapture)
  }

  func testReversedOrderFailsTyped() throws {
    try assertFailsAsPinned(.reversedOrder)
  }

  func testMissingMiddleFailsTyped() throws {
    try assertFailsAsPinned(.missingMiddle)
  }

  func testStickyHeaderFailsTyped() throws {
    try assertFailsAsPinned(.stickyHeader(rows: 12))
  }

  func testStickyFooterFailsTyped() throws {
    try assertFailsAsPinned(.stickyFooter(rows: 12))
  }

  func testFloatingControlFailsTyped() throws {
    try assertFailsAsPinned(.floatingControl(width: 14, height: 14))
  }

  func testHorizontalAxisFailsTyped() throws {
    let bundle = try bundle(.baseline, axis: .horizontal)
    XCTAssertEqual(bundle.groundTruth.expectedFailureCode, "unsupportedAxis")
    XCTAssertThrowsError(
      try engine.reconstruct(CaptureSequence(captures: bundle.captures), axis: .horizontal)
    ) { error in
      XCTAssertEqual((error as? ReconstructionFailure)?.code, "unsupportedAxis")
    }
  }

  func testInvalidConfigurationsAreRejected() {
    XCTAssertThrowsError(
      try FixtureControlGenerator.generate(
        FixtureControlConfiguration(captureCount: 2, variant: .missingMiddle)
      )
    )
    XCTAssertThrowsError(
      try FixtureControlGenerator.generate(
        FixtureControlConfiguration(overlapLength: 8, variant: .onePixelOffset)
      )
    )
    XCTAssertThrowsError(
      try FixtureControlGenerator.generate(
        FixtureControlConfiguration(variant: .degraded(maxChannelDelta: 40))
      )
    )
  }
}
