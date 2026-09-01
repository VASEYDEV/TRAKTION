import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

/// Proof of the docs/tasks/0005 behavior change: at capture scales where the
/// single-pass lower bounds leave every candidate plausible, the old
/// algorithm (refinementRounds: 1) fails closed with resourceLimitExceeded,
/// while adaptive refinement prunes the impostors and reconstructs the same
/// input exactly — with identical fail-closed semantics everywhere else.
final class AdaptiveRefinementTests: XCTestCase {
  /// 400x800 captures with a 300-row overlap: 793 overlap candidates whose
  /// sparse 24x64 sample sums cannot exceed the thresholds against the full
  /// comparison denominator, so one-pass sampling keeps all of them.
  private func largeScaleBundle() throws -> FixtureControlBundle {
    try FixtureControlGenerator.generate(
      FixtureControlConfiguration(
        sourceID: "refinement-trap",
        crossAxisSize: 400,
        viewportLength: 800,
        captureCount: 2,
        overlapLength: 300,
        seed: 41
      )
    )
  }

  func testSinglePassFailsClosedAtScale() throws {
    let bundle = try largeScaleBundle()
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(refinementRounds: 1)
    )
    XCTAssertThrowsError(
      try engine.reconstruct(CaptureSequence(captures: bundle.captures))
    ) { error in
      guard let failure = error as? ReconstructionFailure,
        case .resourceLimitExceeded = failure
      else {
        return XCTFail("expected resourceLimitExceeded, got \(error)")
      }
    }
  }

  func testRefinementReconstructsTheSameInputExactly() throws {
    let bundle = try largeScaleBundle()
    let engine = ReconstructionEngine()

    let first = try engine.reconstruct(CaptureSequence(captures: bundle.captures))
    XCTAssertEqual(first.plan.joints.map(\.overlapRows), bundle.groundTruth.expectedOverlaps)
    XCTAssertEqual(first.plan.joints.map(\.confidence), [.exact])
    XCTAssertEqual(first.image, bundle.source)

    let second = try engine.reconstruct(CaptureSequence(captures: bundle.captures))
    XCTAssertEqual(first.plan, second.plan)
    XCTAssertEqual(first.image, second.image)
  }

  /// Refinement must not weaken any fail-closed path: genuinely ambiguous
  /// content (periodic exact repeats) still refuses, because a true zero
  /// difference can never be pruned by a lower bound.
  func testGenuineAmbiguityStillFailsClosedUnderRefinement() throws {
    let width = 12
    let height = 20
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
      let value = UInt8((y % 4) * 40)
      for x in 0..<width {
        let offset = ((y * width) + x) * 4
        pixels[offset] = value
        pixels[offset + 1] = value
        pixels[offset + 2] = value
        pixels[offset + 3] = 255
      }
    }
    let periodic = try RasterImage(width: width, height: height, pixels: pixels)
    var tailPixels = pixels
    for y in 16..<height {
      let value = UInt8(160 + y)
      for x in 0..<width {
        let offset = ((y * width) + x) * 4
        tailPixels[offset] = value
        tailPixels[offset + 1] = value
        tailPixels[offset + 2] = value
      }
    }
    let withTail = try RasterImage(width: width, height: height, pixels: tailPixels)
    let sequence = CaptureSequence(captures: [
      CaptureAsset(id: "periodic-001", sourceName: "periodic-001.png", image: periodic),
      CaptureAsset(id: "periodic-002", sourceName: "periodic-002.png", image: withTail),
    ])
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(minimumOverlapRows: 4, refinementRounds: 6)
    )
    XCTAssertThrowsError(try engine.reconstruct(sequence)) { error in
      guard let failure = error as? ReconstructionFailure,
        case .ambiguousOverlap(_, _, let rows) = failure
      else {
        return XCTFail("expected ambiguousOverlap, got \(error)")
      }
      XCTAssertEqual(rows, [4, 8, 12, 16])
    }
  }
}
