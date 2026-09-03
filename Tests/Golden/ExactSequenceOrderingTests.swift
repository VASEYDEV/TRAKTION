import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

final class ExactSequenceOrderingTests: XCTestCase {
  func testShuffledExactCapturesRecoverDocumentOrderAndPixels() throws {
    let bundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(sourceID: "unordered", seed: 7001)
    )
    let shuffled = [bundle.captures[2], bundle.captures[0], bundle.captures[1]]

    let result = try ReconstructionEngine().reconstructExactUnordered(shuffled)

    XCTAssertEqual(
      result.plan.placements.map(\.captureID.rawValue),
      bundle.groundTruth.expectedOrder
    )
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), bundle.groundTruth.expectedOverlaps)
    XCTAssertEqual(result.image, bundle.source)
  }

  func testInputPermutationDoesNotChangePlanOrPixels() throws {
    let bundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(sourceID: "deterministic-order", seed: 7002)
    )
    let engine = ReconstructionEngine()

    let first = try engine.reconstructExactUnordered([
      bundle.captures[1], bundle.captures[2], bundle.captures[0],
    ])
    let second = try engine.reconstructExactUnordered([
      bundle.captures[2], bundle.captures[0], bundle.captures[1],
    ])

    XCTAssertEqual(first.plan, second.plan)
    XCTAssertEqual(first.image, second.image)
  }

  func testMissingCoverageFailsWithoutProducingAResult() throws {
    let bundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(sourceID: "gap", seed: 7003, variant: .missingMiddle)
    )

    XCTAssertThrowsError(try ReconstructionEngine().reconstructExactUnordered(bundle.captures)) {
      guard case .sequenceOrderNotFound(let ids) = $0 as? ReconstructionFailure else {
        return XCTFail("expected sequenceOrderNotFound, got \($0)")
      }
      XCTAssertEqual(ids, ids.sorted { $0.rawValue < $1.rawValue })
    }
  }

  func testMultipleCompleteOrdersFailAsAmbiguous() throws {
    let a = try SyntheticFixtureFactory.document(width: 24, height: 32, seed: 1)
    let b = try SyntheticFixtureFactory.document(width: 24, height: 32, seed: 2)
    // Every image shares the same exact eight-row boundary, so both document
    // orders are supported by pixels and neither may be selected silently.
    let sharedRows = Array(a.pixels[(24 * 24 * 4)..<(24 * 32 * 4)])
    func withSharedBoundaries(_ image: RasterImage) throws -> RasterImage {
      var pixels = image.pixels
      pixels.replaceSubrange(0..<(24 * 8 * 4), with: sharedRows)
      pixels.replaceSubrange((24 * 24 * 4)..<(24 * 32 * 4), with: sharedRows)
      return try RasterImage(width: 24, height: 32, pixels: pixels)
    }
    let captures = [
      CaptureAsset(id: "a", sourceName: "a.png", image: try withSharedBoundaries(a)),
      CaptureAsset(id: "b", sourceName: "b.png", image: try withSharedBoundaries(b)),
    ]

    XCTAssertThrowsError(try ReconstructionEngine().reconstructExactUnordered(captures)) {
      guard case .ambiguousSequenceOrder(let orders) = $0 as? ReconstructionFailure else {
        return XCTFail("expected ambiguousSequenceOrder, got \($0)")
      }
      XCTAssertEqual(orders.count, 2)
    }
  }

  func testOrderingBudgetFailsClosedBeforeSelectingAPartialPath() throws {
    let bundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(sourceID: "ordering-budget", seed: 7004)
    )
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(maximumOrderingComparisonPixels: 1)
    )

    XCTAssertThrowsError(try engine.reconstructExactUnordered(bundle.captures)) {
      guard case .resourceLimitExceeded(let reason) = $0 as? ReconstructionFailure else {
        return XCTFail("expected resourceLimitExceeded, got \($0)")
      }
      XCTAssertTrue(reason.contains("sequence ordering"))
    }
  }

  func testOverlapSearchLimitFailsTypedInsteadOfLookingLikeMissingCoverage() throws {
    let bundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(sourceID: "ordering-overlap-limit", seed: 7005)
    )
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(maximumOverlapSearchRows: 32)
    )

    XCTAssertThrowsError(try engine.reconstructExactUnordered(bundle.captures)) {
      guard case .resourceLimitExceeded(let reason) = $0 as? ReconstructionFailure else {
        return XCTFail("expected resourceLimitExceeded, got \($0)")
      }
      XCTAssertTrue(reason.contains("overlap rows"))
    }
  }
}
