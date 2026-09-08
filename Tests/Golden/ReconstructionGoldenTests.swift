import FixtureForgeKit
import TraktionCore
import TraktionDomain
import XCTest

final class ReconstructionGoldenTests: GoldenArtifactTestCase {
  func testExactTwoCaptureReconstructionMatchesSourcePixels() throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let result = try goldenReconstruct(
      expected: fixture.source, captures: fixture.sequence.captures
    ) { try ReconstructionEngine().reconstruct(fixture.sequence) }

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

    let first = try goldenReconstruct(expected: fixture.source, captures: fixture.sequence.captures)
    { try engine.reconstruct(fixture.sequence) }
    let second = try goldenReconstruct(
      expected: fixture.source, captures: fixture.sequence.captures
    ) { try engine.reconstruct(fixture.sequence) }

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

    let first = try goldenReconstruct(expected: source, captures: sequence.captures) {
      try engine.reconstruct(sequence)
    }
    let second = try goldenReconstruct(expected: source, captures: sequence.captures) {
      try engine.reconstruct(sequence)
    }

    XCTAssertEqual(first.plan.joints.map(\.overlapRows), [20])
    XCTAssertEqual(first.plan.joints.map(\.confidence), [.strong])
    XCTAssertEqual(first.image, source)
    XCTAssertEqual(first, second)
  }

  func testShortExactRepeatedBandCannotOverrideLongerNearExactOverlap() throws {
    let width = 40
    let height = 40
    let rowByteCount = width * RasterImage.channelsPerPixel
    let original = try SyntheticFixtureFactory.document(
      width: width,
      height: height,
      seed: 0x4641_4C53
    )
    var sourcePixels = original.pixels

    // Repeat source rows 10...17 at 22...29. For captures beginning at rows
    // 0 and 10, this creates a false exact 8-row placement inside the real
    // 20-row overlap.
    for row in 0..<8 {
      let repeatedStart = (10 + row) * rowByteCount
      let targetStart = (22 + row) * rowByteCount
      let repeatedRow = Array(
        sourcePixels[repeatedStart..<(repeatedStart + rowByteCount)]
      )
      sourcePixels.replaceSubrange(
        targetStart..<(targetStart + rowByteCount),
        with: repeatedRow
      )
    }

    let source = try RasterImage(
      width: width,
      height: height,
      pixels: sourcePixels
    )
    let preceding = try crop(source, startRow: 0, rowCount: 30)
    let following = try crop(source, startRow: 10, rowCount: 30)
    var changedPixels = following.pixels
    let changedOffset = following.byteOffset(x: width / 2, y: 10)
    changedPixels[changedOffset] = changedPixels[changedOffset] > 127 ? 0 : 255

    let sequence = CaptureSequence(captures: [
      CaptureAsset(
        id: "repeated-band-001",
        sourceName: "repeated-band-001.png",
        image: preceding
      ),
      CaptureAsset(
        id: "repeated-band-002",
        sourceName: "repeated-band-002.png",
        image: try RasterImage(
          width: following.width,
          height: following.height,
          pixels: changedPixels
        )
      ),
    ])

    XCTAssertThrowsError(try ReconstructionEngine().reconstruct(sequence)) { error in
      guard let failure = error as? ReconstructionFailure,
        case .ambiguousOverlap(let precedingID, let followingID, let rows) = failure
      else {
        return XCTFail("Expected ambiguousOverlap; received \(error)")
      }
      XCTAssertEqual(precedingID, "repeated-band-001")
      XCTAssertEqual(followingID, "repeated-band-002")
      XCTAssertEqual(rows, [8, 20])
    }
  }

  func testRepeatedLookingRowsRetainTheUniqueAnchoredSequence() throws {
    let fixture = try SyntheticFixtureFactory.repeatedRows()
    let result = try goldenReconstruct(
      expected: fixture.source, captures: fixture.sequence.captures
    ) { try ReconstructionEngine().reconstruct(fixture.sequence) }

    XCTAssertEqual(result.image, fixture.source)
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), fixture.expectedOverlaps)
  }

  func testSolidRepeatedViewportChromeFailsClosed() throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let bandRows = 8
    let captures = try fixture.sequence.captures.map { capture in
      var pixels = capture.image.pixels
      let band = [UInt8](
        repeating: 0,
        count: bandRows * capture.image.rowByteCount
      )
      pixels.replaceSubrange(0..<band.count, with: band)
      pixels.replaceSubrange((pixels.count - band.count)..<pixels.count, with: band)
      return CaptureAsset(
        id: capture.id,
        sourceName: capture.sourceName,
        image: try RasterImage(
          width: capture.image.width,
          height: capture.image.height,
          pixels: pixels
        )
      )
    }

    XCTAssertThrowsError(
      try ReconstructionEngine().reconstruct(CaptureSequence(captures: captures))
    ) {
      XCTAssertEqual(
        $0 as? ReconstructionFailure,
        .repeatedInterfaceArtifact(
          preceding: captures[0].id,
          following: captures[1].id,
          rows: bandRows
        )
      )
    }
  }

  /// Conservative known cost of the task-0010 guard: repeated documentary
  /// content at a viewport edge is indistinguishable from fixed chrome using
  /// byte evidence alone, so it must fail visibly rather than risk corruption.
  func testLegitimateRepeatedContentIsPinnedAsTypedFalseWarning() throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let rows = fixture.expectedOverlaps[0]
    let preceding = fixture.sequence.captures[0]
    let following = fixture.sequence.captures[1]
    var pixels = preceding.image.pixels
    let byteCount = rows * preceding.image.rowByteCount
    pixels.replaceSubrange(0..<byteCount, with: following.image.pixels[0..<byteCount])
    let repeatedPreceding = CaptureAsset(
      id: preceding.id,
      sourceName: preceding.sourceName,
      image: try RasterImage(
        width: preceding.image.width,
        height: preceding.image.height,
        pixels: pixels
      )
    )

    XCTAssertThrowsError(
      try ReconstructionEngine().reconstruct(
        CaptureSequence(captures: [repeatedPreceding, following])
      )
    ) {
      XCTAssertEqual(
        $0 as? ReconstructionFailure,
        .repeatedInterfaceArtifact(
          preceding: preceding.id,
          following: following.id,
          rows: rows
        )
      )
    }
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

  func testNonadjacentDuplicateCaptureFailsBeforeRegistration() throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let duplicate = CaptureAsset(
      id: "duplicate-003",
      sourceName: "duplicate-003.png",
      image: fixture.captures[0].image
    )
    let sequence = CaptureSequence(captures: [
      fixture.captures[0],
      fixture.captures[1],
      duplicate,
    ])

    XCTAssertThrowsError(try ReconstructionEngine().reconstruct(sequence)) {
      XCTAssertEqual(
        $0 as? ReconstructionFailure,
        .duplicateCapture(
          preceding: fixture.captures[0].id,
          following: duplicate.id
        )
      )
    }
  }

  func testFullHeightOverlapAllowsFollowingCaptureToExtendDocument() throws {
    let source = try SyntheticFixtureFactory.document(
      width: 40,
      height: 40,
      seed: 0x5052_4546
    )
    let preceding = try crop(source, startRow: 0, rowCount: 20)
    let sequence = CaptureSequence(captures: [
      CaptureAsset(
        id: "prefix-001",
        sourceName: "prefix-001.png",
        image: preceding
      ),
      CaptureAsset(
        id: "prefix-002",
        sourceName: "prefix-002.png",
        image: source
      ),
    ])

    let result = try goldenReconstruct(expected: source, captures: sequence.captures) {
      try ReconstructionEngine().reconstruct(sequence)
    }

    XCTAssertEqual(result.image, source)
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), [20])
    XCTAssertEqual(result.plan.placements.map(\.originY), [0, 0])
  }

  func testFullHeightFollowingSuffixPreservesTheContainingCapture() throws {
    let source = try SyntheticFixtureFactory.document(width: 40, height: 40, seed: 0x5355_4646)
    let suffix = try crop(source, startRow: 20, rowCount: 20)
    let sequence = CaptureSequence(captures: [
      CaptureAsset(id: "suffix-001", sourceName: "suffix-001.png", image: source),
      CaptureAsset(id: "suffix-002", sourceName: "suffix-002.png", image: suffix),
    ])

    let result = try goldenReconstruct(expected: source, captures: sequence.captures) {
      try ReconstructionEngine().reconstruct(sequence)
    }

    XCTAssertEqual(result.image, source)
    XCTAssertEqual(result.plan.joints.map(\.overlapRows), [20])
    XCTAssertEqual(result.plan.joints.map(\.confidence), [.exact])
    XCTAssertEqual(result.plan.placements.map(\.originY), [0, 20])
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
      XCTAssertEqual(rows, [4, 8, 12, 16])
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
        case .resourceLimitExceeded = failure
      else {
        return XCTFail("Expected resourceLimitExceeded; received \(error)")
      }
    }
  }

  func testCapturePixelLimitIsEnforcedBeforeRegistration() throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let engine = ReconstructionEngine(
      settings: ReconstructionSettings(maximumCapturePixels: 1_000)
    )

    XCTAssertThrowsError(
      try goldenReconstruct(expected: fixture.source, captures: fixture.sequence.captures) {
        try engine.reconstruct(fixture.sequence)
      }
    ) { error in
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

    XCTAssertThrowsError(
      try goldenReconstruct(expected: fixture.source, captures: fixture.sequence.captures) {
        try engine.reconstruct(fixture.sequence)
      }
    ) { error in
      guard let failure = error as? ReconstructionFailure,
        case .resourceLimitExceeded = failure
      else {
        return XCTFail("Expected resourceLimitExceeded; received \(error)")
      }
    }
  }
}

extension ReconstructionGoldenTests {
  fileprivate func crop(
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

  fileprivate func periodicImage(uniqueTail: Bool) throws -> RasterImage {
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
