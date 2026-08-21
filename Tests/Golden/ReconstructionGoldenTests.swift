import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

final class ReconstructionGoldenTests: XCTestCase {
  func testExactTwoCaptureReconstructionMatchesSourcePixels() throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let result = try ReconstructionEngine().reconstruct(fixture.sequence)

    XCTAssertEqual(result.image, fixture.source)
    XCTAssertEqual(
      result.plan.joints.map(\.overlapRows),
      fixture.expectedOverlaps
    )
    XCTAssertEqual(result.plan.joints.map(\.confidence), [.exact])
  }

  func testThreeCaptureReconstructionMatchesSourcePixels() throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let engine = ReconstructionEngine()

    let first = try engine.reconstruct(fixture.sequence)
    let second = try engine.reconstruct(fixture.sequence)

    XCTAssertEqual(first.image, fixture.source)
    XCTAssertEqual(first.plan, second.plan)
    XCTAssertEqual(first.image, second.image)
    XCTAssertEqual(first.plan.joints.map(\.overlapRows), fixture.expectedOverlaps)
  }

  func testBoundedNearExactOverlapUsesTheUniqueRegistration() throws {
    let source = try SyntheticFixtureFactory.document(
      width: 40,
      height: 40,
      seed: 0x5341_4D50
    )
    let preceding = try crop(source, startRow: 0, rowCount: 30)
    let following = try crop(source, startRow: 10, rowCount: 30)
    var changedPixels = following.pixels
    for column in [0, following.width - 1] {
      let offset = following.byteOffset(x: column, y: 0)
      for channel in 0..<3 {
        changedPixels[offset + channel] ^= 255
      }
    }
    let changedFollowing = CaptureAsset(
      id: "sampled-002",
      sourceName: "sampled-002.png",
      image: try RasterImage(
        width: following.width,
        height: following.height,
        pixels: changedPixels
      )
    )
    let sequence = CaptureSequence(
      captures: [
        CaptureAsset(
          id: "sampled-001",
          sourceName: "sampled-001.png",
          image: preceding
        ),
        changedFollowing,
      ]
    )
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(
        sampledRows: 2,
        sampledColumns: 2,
        candidateLimit: 64
      )
    )

    let first = try engine.reconstruct(sequence)
    let second = try engine.reconstruct(sequence)

    XCTAssertEqual(first.plan.joints.map(\.overlapRows), [20])
    XCTAssertEqual(first.plan.joints.map(\.confidence), [.strong])
    XCTAssertEqual(first.image, source)
    XCTAssertEqual(first, second)
  }

  func testRepeatedLookingRowsRetainTheUniqueAnchoredSequence() throws {
    let fixture = try SyntheticFixtureFactory.repeatedRows()
    let result = try ReconstructionEngine().reconstruct(fixture.sequence)

    XCTAssertEqual(result.image, fixture.source)
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), fixture.expectedOverlaps)
  }

  func testInsufficientOverlapFailsClosed() throws {
    let sequence = try SyntheticFixtureFactory.unrelatedPair()
    let expected = ReconstructionFailure.insufficientOverlap(
      preceding: sequence.captures[0].id,
      following: sequence.captures[1].id,
      minimumRows: 8
    )

    XCTAssertThrowsError(try ReconstructionEngine().reconstruct(sequence)) {
      XCTAssertEqual($0 as? ReconstructionFailure, expected)
    }
  }

  func testWidthMismatchFailsBeforeRegistration() throws {
    let sequence = try SyntheticFixtureFactory.widthMismatchPair()
    let expected = ReconstructionFailure.incompatibleDimensions(
      expectedWidth: sequence.captures[0].image.width,
      actualWidth: sequence.captures[1].image.width,
      captureID: sequence.captures[1].id
    )

    XCTAssertThrowsError(try ReconstructionEngine().reconstruct(sequence)) {
      XCTAssertEqual($0 as? ReconstructionFailure, expected)
    }
  }

  func testDuplicateCaptureFailsClosed() throws {
    let sequence = try SyntheticFixtureFactory.duplicatePair()
    let expected = ReconstructionFailure.duplicateCapture(
      preceding: sequence.captures[0].id,
      following: sequence.captures[1].id
    )

    XCTAssertThrowsError(try ReconstructionEngine().reconstruct(sequence)) {
      XCTAssertEqual($0 as? ReconstructionFailure, expected)
    }
  }

  func testHorizontalAxisIsExplicitlyUnsupported() throws {
    let sequence = try SyntheticFixtureFactory.exactTwoCapture().sequence
    XCTAssertThrowsError(
      try ReconstructionEngine().reconstruct(sequence, axis: .horizontal)
    ) {
      XCTAssertEqual(
        $0 as? ReconstructionFailure,
        .unsupportedAxis(.horizontal)
      )
    }
  }

  func testMultipleExactPeriodicOverlapsAreReportedAsAmbiguous() throws {
    let first = try periodicImage(uniqueTail: false)
    let second = try periodicImage(uniqueTail: true)
    let sequence = CaptureSequence(captures: [
      CaptureAsset(id: "periodic-001", sourceName: "periodic-001.png", image: first),
      CaptureAsset(id: "periodic-002", sourceName: "periodic-002.png", image: second),
    ])
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(minimumOverlapRows: 4)
    )

    XCTAssertThrowsError(try engine.reconstruct(sequence)) { error in
      guard let failure = error as? ReconstructionFailure else {
        return XCTFail("Expected ReconstructionFailure; received \(error)")
      }
      guard case .ambiguousOverlap(let preceding, let following, let rows) = failure else {
        return XCTFail("Expected ambiguousOverlap; received \(error)")
      }
      XCTAssertEqual(preceding, "periodic-001")
      XCTAssertEqual(following, "periodic-002")
      XCTAssertEqual(rows.count, 2)
    }
  }

  func testCandidateBudgetFailsClosedInsteadOfSelectingAnArbitraryOverlap() throws {
    let first = try periodicImage(uniqueTail: false)
    let second = try periodicImage(uniqueTail: true)
    let sequence = CaptureSequence(captures: [
      CaptureAsset(id: "budget-001", sourceName: "budget-001.png", image: first),
      CaptureAsset(id: "budget-002", sourceName: "budget-002.png", image: second),
    ])
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(
        minimumOverlapRows: 4,
        candidateLimit: 2
      )
    )

    XCTAssertThrowsError(try engine.reconstruct(sequence)) { error in
      guard let failure = error as? ReconstructionFailure,
        case .ambiguousOverlap = failure
      else {
        return XCTFail("Expected ambiguousOverlap; received \(error)")
      }
    }
  }

  func testCapturePixelLimitIsEnforcedBeforeRegistration() throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(maximumCapturePixels: 1_000)
    )

    XCTAssertThrowsError(try engine.reconstruct(fixture.sequence)) { error in
      guard let failure = error as? ReconstructionFailure,
        case .resourceLimitExceeded = failure
      else {
        return XCTFail("Expected resourceLimitExceeded; received \(error)")
      }
    }
  }

  func testFullComparisonBudgetFailsClosed() throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(
        maximumFullComparisonPixelsPerJoint: 1
      )
    )

    XCTAssertThrowsError(try engine.reconstruct(fixture.sequence)) { error in
      guard let failure = error as? ReconstructionFailure,
        case .resourceLimitExceeded = failure
      else {
        return XCTFail("Expected resourceLimitExceeded; received \(error)")
      }
    }
  }
}

private extension ReconstructionGoldenTests {
  func crop(
    _ image: RasterImage,
    startRow: Int,
    rowCount: Int
  ) throws -> RasterImage {
    let start = startRow * image.rowByteCount
    let end = (startRow + rowCount) * image.rowByteCount
    return try RasterImage(
      width: image.width,
      height: rowCount,
      pixels: Array(image.pixels[start..<end])
    )
  }

  func periodicImage(uniqueTail: Bool) throws -> RasterImage {
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
