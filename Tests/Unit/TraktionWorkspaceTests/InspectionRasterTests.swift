import FixtureForgeKit
import TraktionCore
import TraktionDomain
@testable import TraktionUI
import XCTest

final class InspectionRasterTests: XCTestCase {
  func testOneToOneAndMagnifiedPixelsMatchIndependentSourceCoordinates() throws {
    let source = try SyntheticFixtureFactory.document(width: 97, height: 219, seed: 78)
    let original = source.pixels
    for zoom in [0.5, 1, 2, 4] {
      let viewport = try InspectionViewport(width: 43, height: 51, x: 7, y: 83, zoom: zoom)
      let frame = try InspectionRasterRenderer().render(source, viewport: viewport, isCancelled: { false })
      var expected: [UInt8] = []
      // Independent oracle reads per-coordinate channels, not the renderer/crop helper.
      for row in 0..<51 {
        for column in 0..<43 {
          let offset = ((83 + Int(Double(row) / zoom)) * 97 + 7 + Int(Double(column) / zoom)) * 4
          expected.append(contentsOf: original[offset..<offset + 4])
        }
      }
      XCTAssertEqual(frame.raster.pixels, expected)
    }
    XCTAssertEqual(source.pixels, original)
  }

  func testOutsideSourceIsTransparentAndLastRowAndColumnArePreserved() throws {
    let source = try SyntheticFixtureFactory.document(width: 13, height: 17, seed: 81)
    let viewport = try InspectionViewport(width: 4, height: 4, x: 12, y: 16, zoom: 1)
    let frame = try InspectionRasterRenderer().render(source, viewport: viewport, isCancelled: { false })
    XCTAssertEqual(Array(frame.raster.pixels[0..<4]), Array(source.pixels.suffix(4)))
    XCTAssertEqual(Array(frame.raster.pixels[4...]), [UInt8](repeating: 0, count: 60))
  }

  func testViewportRejectsUnboundedAndNonfiniteRequestsBeforeRendering() throws {
    for size in [0, -1, 1_025, Int.max] {
      XCTAssertThrowsError(try InspectionViewport(width: size, height: 1, x: 0, y: 0, zoom: 1))
    }
    for zoom in [0, -1, .infinity, .nan, 17] {
      XCTAssertThrowsError(try InspectionViewport(width: 1, height: 1, x: 0, y: 0, zoom: zoom))
    }
    XCTAssertThrowsError(try InspectionViewport(width: 1, height: 1, x: .infinity, y: 0, zoom: 1))
    let image = try SyntheticFixtureFactory.document(width: 8, height: 8, seed: 1)
    XCTAssertThrowsError(try InspectionRasterRenderer().render(image,
      viewport: InspectionViewport(width: 1, height: 1, x: 8, y: 0, zoom: 1), isCancelled: { false }))
    XCTAssertThrowsError(try InspectionRasterRenderer().render(image,
      viewport: InspectionViewport(width: 1, height: 1, x: 0, y: 0, zoom: 1), isCancelled: { true }))
  }

  func testEveryJointResolvesStableIDsAndMatchesOriginalSeamRegions() throws {
    let fixture = try SyntheticFixtureFactory.baseline()
    let result = try ReconstructionEngine().reconstruct(fixture.sequence, axis: .vertical)
    // Input array is deliberately reversed, with identical basenames.
    let captures = fixture.captures.reversed().map {
      CaptureAsset(id: $0.id, sourceName: "same-name.png", image: $0.image)
    }
    for (index, diagnosis) in result.plan.joints.enumerated() {
      let joint = try InspectionJoint(diagnosis, result: result, captures: captures)
      XCTAssertEqual(joint.preceding.id, fixture.captures[index].id)
      XCTAssertEqual(joint.following.id, fixture.captures[index + 1].id)
      XCTAssertEqual(joint.followingOrigin, fixture.sourceOrigins[index + 1])
      XCTAssertEqual(joint.diagnosis.confidence, .exact)
      let row = diagnosis.outputSeamRow
      let resultFrame = try InspectionRasterRenderer().render(result.image,
        viewport: InspectionViewport(width: 32, height: 10, x: 3, y: Double(row - 5), zoom: 1),
        isCancelled: { false })
      var oracle: [UInt8] = []
      for y in row - 5..<row + 5 {
        for x in 3..<35 {
          let offset = (y * fixture.source.width + x) * 4
          oracle.append(contentsOf: fixture.source.pixels[offset..<offset + 4])
        }
      }
      XCTAssertEqual(resultFrame.raster.pixels, oracle)
      for (capture, seam) in [(joint.preceding, joint.precedingSeamRow), (joint.following, joint.followingSeamRow)] {
        let sourceFrame = try InspectionRasterRenderer().render(capture.image,
          viewport: InspectionViewport(width: 32, height: 10, x: 3, y: Double(seam - 5), zoom: 1),
          isCancelled: { false })
        XCTAssertEqual(sourceFrame.raster.pixels, oracle)
      }
    }
    XCTAssertThrowsError(try InspectionJoint(result.plan.joints[0], result: result, captures: []))
  }

  func testLongResultUsesSameBoundedFrameAtTopMiddleBottomAndFit() throws {
    let source = try SyntheticFixtureFactory.document(width: 1_170, height: 19_020, seed: 52)
    let renderer = InspectionRasterRenderer()
    for y in [0, 9_000, 18_300] {
      let frame = try renderer.render(source,
        viewport: InspectionViewport(width: 960, height: 720, x: 100, y: Double(y), zoom: 1),
        isCancelled: { false })
      XCTAssertEqual(frame.raster.pixels.count, 960 * 720 * 4)
      for (x, row) in [(0, 0), (479, 359), (959, 719)] {
        let actual = (row * 960 + x) * 4
        let expected = ((row + y) * 1_170 + x + 100) * 4
        XCTAssertEqual(Array(frame.raster.pixels[actual..<actual + 4]), Array(source.pixels[expected..<expected + 4]))
      }
    }
    let fit = try renderer.render(source,
      viewport: InspectionViewport(width: 960, height: 720, x: 0, y: 0, zoom: 720.0 / 19_020),
      isCancelled: { false })
    XCTAssertEqual(fit.raster.pixels.count, 960 * 720 * 4)
    XCTAssertLessThanOrEqual(fit.raster.pixels.count, InspectionViewport.maximumBytes)
  }
}
