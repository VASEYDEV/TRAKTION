import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

/// Preserve the original task-0014 evidence independently of the anchored
/// positive FixtureForge style. Adding a gutter to that style did not repair
/// the engine's acceptance of this coverage gap.
final class MonospacedCoverageGapTests: GoldenArtifactTestCase {
  func testPreGutterMissingMiddleFailsClosedDeterministically() throws {
    let fixture = try missingMiddleFixture()
    let captures = fixture.captures
    XCTAssertEqual(exhaustiveOverlaps(captures[0].image, captures[1].image), [57])
    XCTAssertEqual(exhaustiveOverlaps(captures[1].image, captures[0].image), [30])
    let expected = ReconstructionFailure.ambiguousOverlapDirection(
      preceding: captures[0].id,
      following: captures[1].id,
      forwardRows: 57,
      reverseRows: [30]
    )
    for _ in 0..<2 {
      XCTAssertThrowsError(
        try goldenReconstruct(expected: fixture.source, captures: captures) {
          try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures))
        }
      ) {
        XCTAssertEqual($0 as? ReconstructionFailure, expected)
      }
    }
  }

  func testNearExactOrderingStillRejectsBothDocumentaryDirections() throws {
    let fixture = try missingMiddleFixture()
    let captures = fixture.captures
    for order in [captures, Array(captures.reversed())] {
      XCTAssertThrowsError(
        try goldenReconstruct(expected: fixture.source, captures: order) {
          try ReconstructionEngine().reconstructNearExactUnordered(order)
        }
      ) {
        XCTAssertEqual(($0 as? ReconstructionFailure)?.code, "ambiguousSequenceOrder")
      }
    }
  }

  func testMultipleReversePlacementsAlsoRequireReview() throws {
    let repeatBand = try SyntheticFixtureFactory.document(width: 64, height: 16, seed: 8100)
    let forwardBand = try SyntheticFixtureFactory.document(width: 64, height: 32, seed: 8200)
    var noisyForward = forwardBand.pixels
    noisyForward[0] ^= 1
    let preceding = CaptureAsset(
      id: "direction-001",
      sourceName: "direction-001.png",
      image: try RasterImage(
        width: 64,
        height: 64,
        pixels: repeatBand.pixels + repeatBand.pixels + forwardBand.pixels
      )
    )
    let following = CaptureAsset(
      id: "direction-002",
      sourceName: "direction-002.png",
      image: try RasterImage(
        width: 64,
        height: 64,
        pixels: noisyForward + repeatBand.pixels + repeatBand.pixels
      )
    )
    XCTAssertThrowsError(
      try ReconstructionEngine().reconstruct(CaptureSequence(captures: [preceding, following]))
    ) {
      XCTAssertEqual(
        $0 as? ReconstructionFailure,
        .ambiguousOverlapDirection(
          preceding: preceding.id, following: following.id, forwardRows: 32, reverseRows: [16, 32]
        )
      )
    }
  }

  func testReverseRowBoundsPreserveAcceptedMatchesWithDifferentChannelSums() throws {
    let firstBand = try SyntheticFixtureFactory.document(width: 64, height: 32, seed: 8400)
    let secondBand = try SyntheticFixtureFactory.document(width: 64, height: 32, seed: 8500)
    var noisyPixels = secondBand.pixels + firstBand.pixels
    for offset in stride(from: 0, to: noisyPixels.count, by: 4) {
      for channel in 0..<3 {
        // The generated RGB values are below 255. Every aligned row's RGB
        // sum differs by 64, yet both overlaps satisfy unchanged thresholds.
        noisyPixels[offset + channel] += 1
      }
    }
    let first = CaptureAsset(
      id: "row-bounds-001",
      sourceName: "row-bounds-001.png",
      image: try RasterImage(width: 64, height: 64, pixels: firstBand.pixels + secondBand.pixels)
    )
    let second = CaptureAsset(
      id: "row-bounds-002",
      sourceName: "row-bounds-002.png",
      image: try RasterImage(width: 64, height: 64, pixels: noisyPixels)
    )
    let forwardRows = exhaustiveOverlaps(first.image, second.image)
    let reverseRows = exhaustiveOverlaps(second.image, first.image)
    XCTAssertEqual(forwardRows, [32])
    XCTAssertEqual(reverseRows, [32])
    XCTAssertThrowsError(
      try ReconstructionEngine().reconstruct(CaptureSequence(captures: [first, second]))
    ) {
      XCTAssertEqual(
        $0 as? ReconstructionFailure,
        .ambiguousOverlapDirection(
          preceding: first.id, following: second.id, forwardRows: 32, reverseRows: reverseRows
        )
      )
    }
  }

  func testReverseRowBoundsOnlyScanTheSearchedCaptureRegions() throws {
    let source = try SyntheticFixtureFactory.document(width: 64, height: 4112, seed: 8600)
    let rowBytes = source.rowByteCount
    var followingPixels = Array(source.pixels[(4080 * rowBytes)..<(4112 * rowBytes)])
    for offset in stride(from: 0, to: followingPixels.count, by: 4) {
      for channel in 0..<3 { followingPixels[offset + channel] += 1 }
    }
    let captures = [
      CaptureAsset(
        id: "tall-001", sourceName: "tall-001.png",
        image: try RasterImage(
          width: 64, height: 4096, pixels: Array(source.pixels[0..<(4096 * rowBytes)])
        )
      ),
      CaptureAsset(
        id: "tall-002", sourceName: "tall-002.png",
        image: try RasterImage(width: 64, height: 32, pixels: followingPixels)
      ),
    ]
    let result = try ReconstructionEngine(
      settings: ReconstructionSettings(
        maximumOverlapSearchRows: 32,
        maximumSampleComparisonsPerJoint: 65_536
      )
    ).reconstruct(CaptureSequence(captures: captures))
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), [16])
    XCTAssertEqual(result.plan.joints.map(\.confidence), [.strong])
    XCTAssertEqual(result.image.height, source.height)
  }

  func testReverseEvidenceSharesTheJointSampleBudget() throws {
    let fixture = try missingMiddleFixture()
    let captures = fixture.captures
    // Full sampling spends exactly sum(8...96) * 64 = 296192 pixels in
    // the forward probe. The first reverse row must exhaust that budget.
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(
        sampledRows: 96,
        maximumSampleComparisonsPerJoint: 296_192
      )
    )
    XCTAssertThrowsError(
      try goldenReconstruct(expected: fixture.source, captures: captures) {
        try engine.reconstruct(CaptureSequence(captures: captures))
      }
    ) {
      guard case .resourceLimitExceeded(let reason) = $0 as? ReconstructionFailure else {
        return XCTFail("Expected shared sample-budget refusal, received \($0)")
      }
      XCTAssertTrue(reason.contains("monospaced-003/monospaced-001"))
      XCTAssertTrue(reason.contains("sample search"))
    }
  }

  func testReverseEvidenceSharesTheJointFullComparisonBudget() throws {
    let fixture = try missingMiddleFixture()
    let captures = fixture.captures
    // Complete sampling leaves only the unique 57-row forward candidate.
    // Its full score spends 3648 pixels; the 30-row reverse candidate must
    // not obtain a fresh per-joint allowance.
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(
        sampledRows: 96,
        maximumFullComparisonPixelsPerJoint: 57 * 64
      )
    )
    XCTAssertThrowsError(
      try goldenReconstruct(expected: fixture.source, captures: captures) {
        try engine.reconstruct(CaptureSequence(captures: captures))
      }
    ) {
      guard case .resourceLimitExceeded(let reason) = $0 as? ReconstructionFailure else {
        return XCTFail("Expected shared full-budget refusal, received \($0)")
      }
      XCTAssertTrue(reason.contains("monospaced-003/monospaced-001"))
      XCTAssertTrue(reason.contains("full verification"))
    }
  }

  func testAnchoredMonospacedPositiveAndMissingControlsArePreserved() throws {
    let baseline = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(seed: 5040, contentStyle: .monospacedCode)
    )
    let result = try goldenReconstruct(expected: baseline.source, captures: baseline.captures) {
      try ReconstructionEngine().reconstruct(CaptureSequence(captures: baseline.captures))
    }
    XCTAssertEqual(result.image, baseline.source)
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), [24, 24])

    let missing = try FixtureControlGenerator.generate(
      FixtureControlConfiguration(
        seed: 5041, variant: .missingMiddle, contentStyle: .monospacedCode
      )
    )
    XCTAssertThrowsError(
      try goldenReconstruct(expected: missing.source, captures: missing.captures) {
        try ReconstructionEngine().reconstruct(CaptureSequence(captures: missing.captures))
      }
    ) {
      XCTAssertEqual(($0 as? ReconstructionFailure)?.code, "insufficientOverlap")
    }
  }
}

private extension MonospacedCoverageGapTests {
  /// Independent exhaustive oracle: no row summaries, sampling, candidate
  /// ranking, or adaptive bounds. Small inputs keep the full search bounded.
  func exhaustiveOverlaps(_ preceding: RasterImage, _ following: RasterImage) -> [Int] {
    let settings = ReconstructionSettings()
    return (settings.minimumOverlapRows...min(preceding.height, following.height)).filter { rows in
      var totalDifference: UInt64 = 0
      var changedPixels = 0
      for row in 0..<rows {
        for column in 0..<preceding.width {
          let precedingOffset = preceding.byteOffset(x: column, y: preceding.height - rows + row)
          let followingOffset = following.byteOffset(x: column, y: row)
          var changed = false
          for channel in 0..<4 {
            let difference = abs(
              Int(preceding.pixels[precedingOffset + channel])
                - Int(following.pixels[followingOffset + channel])
            )
            totalDifference += UInt64(difference)
            changed = changed || difference > Int(settings.changedChannelThreshold)
          }
          if changed { changedPixels += 1 }
        }
      }
      let pixelCount = rows * preceding.width
      return Double(totalDifference) / (Double(pixelCount) * 4 * 255)
        <= settings.maximumNormalizedMeanAbsoluteError
        && Double(changedPixels) / Double(pixelCount) <= settings.maximumChangedPixelFraction
    }
  }

  func missingMiddleFixture() throws -> (source: RasterImage, captures: [CaptureAsset]) {
    let width = 64
    let height = 240
    let seed: UInt64 = 5041
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        let noise = UInt8(truncatingIfNeeded: seed &+ UInt64(x * 31) &+ UInt64(y * 17))
        let glyph = x >= max(4, width / 12)
          && (x / 4 + y / 7 + Int(seed & 7)) % 5 < 2
          && y % 7 < 5
        let variation = noise % 7
        let offset = (y * width + x) * 4
        pixels[offset] = (glyph ? 38 : 235) &+ variation
        pixels[offset + 1] = (glyph ? 52 : 238) &+ variation
        pixels[offset + 2] = (glyph ? 68 : 241) &+ variation
      }
    }
    // The omitted middle capture begins at 72. These remaining windows
    // occupy 0..<96 and 144..<240: an actual 48-row documentary gap.
    let captures = try [("monospaced-001", 0), ("monospaced-003", 144)].map { name, origin in
      let start = origin * width * 4
      return CaptureAsset(
        id: CaptureID(rawValue: name),
        sourceName: "\(name).png",
        image: try RasterImage(
          width: width,
          height: 96,
          pixels: Array(pixels[start..<(start + 96 * width * 4)])
        )
      )
    }
    return (try RasterImage(width: width, height: height, pixels: pixels), captures)
  }
}
