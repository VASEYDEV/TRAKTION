import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

/// Golden coverage for automatic order recovery (docs/tasks/0006, ADR-014).
/// Recovery must reproduce the documentary order only when it is uniquely
/// provable from pixel evidence; every other outcome is a typed refusal and
/// never a composite.
final class OrderRecoveryTests: XCTestCase {
  private let engine = ReconstructionEngine()

  private func baselineBundle(
    captureCount: Int,
    seed: UInt64 = 4242
  ) throws -> FixtureControlBundle {
    try FixtureControlGenerator.generate(
      FixtureControlConfiguration(
        sourceID: "order",
        captureCount: captureCount,
        seed: seed,
        variant: .baseline
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
  /// direction has exactly one acceptable overlap: the documentary order is
  /// genuinely unprovable.
  private func symmetricPair() throws -> [CaptureAsset] {
    let bandX = try SyntheticFixtureFactory.document(width: 64, height: 40, seed: 900)
    let bandY = try SyntheticFixtureFactory.document(width: 64, height: 40, seed: 901)
    return [
      CaptureAsset(id: "sym-a", sourceName: "sym-a.png", image: try stacked(bandX, bandY)),
      CaptureAsset(id: "sym-b", sourceName: "sym-b.png", image: try stacked(bandY, bandX)),
    ]
  }

  // MARK: - Recovery of provable orders

  func testShuffledCapturesRecoverGroundTruthOrder() throws {
    let bundle = try baselineBundle(captureCount: 5)
    let shuffled = [2, 4, 0, 3, 1].map { bundle.captures[$0] }

    let recovered = try engine.recoverOrder(shuffled)
    XCTAssertEqual(
      recovered.captureIDs.map(\.rawValue),
      bundle.groundTruth.expectedOrder
    )
    XCTAssertEqual(recovered.edges.count, 4)
    for edge in recovered.edges {
      XCTAssertEqual(edge.confidence, .exact)
      XCTAssertEqual(edge.candidate.overlapRows, 24)
      XCTAssertEqual(edge.candidate.normalizedMeanAbsoluteError, 0)
    }

    let reconstruction = try engine.reconstructRecoveringOrder(shuffled)
    XCTAssertEqual(reconstruction.order, recovered)
    XCTAssertEqual(reconstruction.result.image, bundle.source)
  }

  func testFullyReversedCapturesRecover() throws {
    let bundle = try baselineBundle(captureCount: 3)
    let reversed = Array(bundle.captures.reversed())

    let reconstruction = try engine.reconstructRecoveringOrder(reversed)
    XCTAssertEqual(
      reconstruction.order.captureIDs.map(\.rawValue),
      bundle.groundTruth.expectedOrder
    )
    XCTAssertEqual(reconstruction.result.image, bundle.source)
  }

  func testAlreadyOrderedCapturesMatchSuppliedOrderPath() throws {
    let bundle = try baselineBundle(captureCount: 3)
    let supplied = try engine.reconstruct(
      CaptureSequence(captures: bundle.captures)
    )
    let recovered = try engine.reconstructRecoveringOrder(bundle.captures)
    XCTAssertEqual(recovered.result.plan, supplied.plan)
    XCTAssertEqual(recovered.result.image, supplied.image)
  }

  // MARK: - Typed refusals

  func testSymmetricPairFailsAsAmbiguousOrder() throws {
    let captures = try symmetricPair()
    XCTAssertThrowsError(try engine.recoverOrder(captures)) { error in
      guard let failure = error as? ReconstructionFailure,
        case .ambiguousOrder(let orders, let total) = failure
      else {
        return XCTFail("Expected ambiguousOrder; received \(error)")
      }
      XCTAssertEqual(total, 2)
      XCTAssertEqual(
        orders.map { $0.map(\.rawValue) },
        [["sym-a", "sym-b"], ["sym-b", "sym-a"]]
      )
      XCTAssertEqual(failure.code, "ambiguousOrder")
    }
  }

  func testMissingMiddleFailsAsMissingCoverage() throws {
    let bundle = try baselineBundle(captureCount: 4)
    // Drop the second capture, then shuffle what remains: only 2 → 3 stays
    // provable, so no order can cover all three captures.
    let gapped = [2, 0, 3].map { bundle.captures[$0] }

    XCTAssertThrowsError(try engine.recoverOrder(gapped)) { error in
      guard let failure = error as? ReconstructionFailure,
        case .missingCoverage(let covered, let uncovered) = failure
      else {
        return XCTFail("Expected missingCoverage; received \(error)")
      }
      XCTAssertEqual(
        covered.map(\.rawValue),
        [bundle.captures[2].id.rawValue, bundle.captures[3].id.rawValue]
      )
      XCTAssertEqual(uncovered.map(\.rawValue), [bundle.captures[0].id.rawValue])
      XCTAssertEqual(failure.code, "missingCoverage")
    }
  }

  func testPairLevelAmbiguityNeverBecomesAnEdge() throws {
    // The periodic pair is ambiguous at every offset in the forward
    // direction (rows [4, 8, 12, 16], pinned by the supplied-order golden)
    // and has no acceptable reverse overlap: recovery must refuse rather
    // than route through unprovable evidence.
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

    XCTAssertThrowsError(try engine.recoverOrder(captures)) { error in
      guard let failure = error as? ReconstructionFailure,
        case .missingCoverage(let covered, let uncovered) = failure
      else {
        return XCTFail("Expected missingCoverage; received \(error)")
      }
      XCTAssertEqual(covered.map(\.rawValue), ["periodic-001"])
      XCTAssertEqual(uncovered.map(\.rawValue), ["periodic-002"])
    }
  }

  func testTinyBudgetsFailClosedDuringGraphConstruction() throws {
    let bundle = try baselineBundle(captureCount: 3)
    let starved = ReconstructionEngine(
      settings: ReconstructionSettings(maximumSampleComparisonsPerJoint: 1)
    )
    XCTAssertThrowsError(
      try starved.recoverOrder([2, 0, 1].map { bundle.captures[$0] })
    ) { error in
      guard let failure = error as? ReconstructionFailure,
        case .resourceLimitExceeded = failure
      else {
        return XCTFail("Expected resourceLimitExceeded; received \(error)")
      }
    }
  }

  func testByteIdenticalDuplicatesStayTypedFailures() throws {
    let bundle = try baselineBundle(captureCount: 3)
    let copy = CaptureAsset(
      id: "copy",
      sourceName: "copy.png",
      image: bundle.captures[0].image
    )
    XCTAssertThrowsError(
      try engine.recoverOrder([bundle.captures[0], copy])
    ) { error in
      guard let failure = error as? ReconstructionFailure,
        case .duplicateCapture = failure
      else {
        return XCTFail("Expected duplicateCapture; received \(error)")
      }
    }
  }

  func testCaptureCountBoundsApply() throws {
    let bundle = try baselineBundle(captureCount: 3)
    XCTAssertThrowsError(try engine.recoverOrder([bundle.captures[0]])) {
      XCTAssertEqual(
        $0 as? ReconstructionFailure,
        .captureCountOutOfRange(actual: 1, allowed: 2...10)
      )
    }
  }

  // MARK: - Determinism and contracts

  func testRecoveryIsDeterministic() throws {
    let bundle = try baselineBundle(captureCount: 5)
    let shuffled = [4, 1, 3, 0, 2].map { bundle.captures[$0] }

    let first = try engine.reconstructRecoveringOrder(shuffled)
    let second = try engine.reconstructRecoveringOrder(shuffled)
    XCTAssertEqual(first.order, second.order)
    XCTAssertEqual(first.result.plan, second.result.plan)
    XCTAssertEqual(first.result.image, second.result.image)

    let symmetric = try symmetricPair()
    var payloads: [ReconstructionFailure] = []
    for _ in 0..<2 {
      XCTAssertThrowsError(try engine.recoverOrder(symmetric)) { error in
        if let failure = error as? ReconstructionFailure {
          payloads.append(failure)
        }
      }
    }
    XCTAssertEqual(payloads.count, 2)
    XCTAssertEqual(payloads[0], payloads[1])
  }

  func testNewFailurePayloadsRoundTripThroughCodable() throws {
    let failures: [ReconstructionFailure] = [
      .ambiguousOrder(
        candidateOrders: [["a", "b"], ["b", "a"]],
        totalCandidates: 2
      ),
      .missingCoverage(coveredCaptureIDs: ["a", "b"], uncoveredCaptureIDs: ["c"]),
    ]
    for failure in failures {
      let encoded = try JSONEncoder().encode(failure)
      let decoded = try JSONDecoder().decode(
        ReconstructionFailure.self,
        from: encoded
      )
      XCTAssertEqual(decoded, failure)
    }
    XCTAssertEqual(failures[0].code, "ambiguousOrder")
    XCTAssertEqual(failures[1].code, "missingCoverage")
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
