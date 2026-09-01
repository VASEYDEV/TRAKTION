import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

/// Phone-scale calibration proof (docs/tasks/0005): a 1170x2532 capture pair
/// registers and reconstructs within the default budgets. Bound is generous —
/// this guards against pathological regressions, not benchmarks.
final class PhoneScaleReconstructionTests: XCTestCase {
  func testPhoneScalePairReconstructsWithinDefaultBudgets() throws {
    let bundle = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(
        sourceID: "phone-scale",
        crossAxisSize: 1170,
        viewportLength: 2532,
        captureCount: 2,
        overlapLength: 700,
        seed: 51
      )
    )

    let clock = ContinuousClock()
    let start = clock.now
    let result = try ReconstructionEngine().reconstruct(
      CaptureSequence(captures: bundle.captures)
    )
    let elapsed = start.duration(to: clock.now)

    XCTAssertEqual(result.plan.joints.map(\.overlapRows), bundle.groundTruth.expectedOverlaps)
    XCTAssertEqual(result.image, bundle.source)
    XCTAssertLessThan(
      elapsed,
      .seconds(240),
      "phone-scale registration took \(elapsed); investigate a pathological regression"
    )
    print("TRAKTION_PERF phone-scale 1170x2532 pair: \(elapsed)")
  }
}
