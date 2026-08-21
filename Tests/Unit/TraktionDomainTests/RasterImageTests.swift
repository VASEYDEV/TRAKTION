import XCTest
@testable import TraktionDomain

final class RasterImageTests: XCTestCase {
  func testRejectsNonPositiveDimensions() {
    XCTAssertThrowsError(try RasterImage(width: 0, height: 1, pixels: [])) {
      XCTAssertEqual(
        $0 as? RasterImageError,
        .invalidDimensions(width: 0, height: 1)
      )
    }
  }

  func testRejectsMismatchedPixelStorage() {
    XCTAssertThrowsError(
      try RasterImage(width: 2, height: 2, pixels: [UInt8](repeating: 0, count: 15))
    ) {
      XCTAssertEqual(
        $0 as? RasterImageError,
        .pixelCountMismatch(expected: 16, actual: 15)
      )
    }
  }

  func testCaptureIDStringLiteralIsStable() {
    let identifier: CaptureID = "capture-001"
    XCTAssertEqual(identifier.rawValue, "capture-001")
    XCTAssertEqual(identifier.description, "capture-001")
  }
}
