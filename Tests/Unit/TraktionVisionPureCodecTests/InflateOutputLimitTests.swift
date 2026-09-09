import Foundation
import XCTest

@testable import TraktionVision

final class InflateOutputLimitTests: XCTestCase {
  // Independent CPython zlib vectors: a literal-only fixed block, a fixed
  // block with overlapping matches, and a dynamic block with matches.
  private let vectors: [(blockType: Int, base64: String, output: [UInt8])] = [
    (1, "eNpLTEoGAAJNASc=", Array("abc".utf8)),
    (1, "eNpzdBwFxAIAy55MLQ==", [UInt8](repeating: 65, count: 300)),
    (
      2,
      "eNrtyUsCQCAAQMF8I6UoIcn9b9klLN9sRzRt1w+jnGa1aLNat+0+HPG87vTkt3yC53me53me53n+p696ecHB",
      (0..<3200).map { UInt8($0 % 32) }
    ),
  ]

  func testExactLimitPreservesFixedAndDynamicStreams() throws {
    for vector in vectors {
      let compressed = [UInt8](try XCTUnwrap(Data(base64Encoded: vector.base64)))
      XCTAssertEqual(Int((compressed[2] >> 1) & 3), vector.blockType)
      XCTAssertEqual(
        try PureZlib.decompress(compressed, outputLimit: vector.output.count), vector.output
      )
      for limit in [0, 2, vector.output.count - 1] {
        XCTAssertThrowsError(try PureZlib.decompress(compressed, outputLimit: limit)) {
          XCTAssertEqual($0 as? PureInflateError, .outputLimitExceeded(limit: limit))
        }
      }
    }
  }

  func testStoredLimitIncludesPreviousBlocks() throws {
    let output = (0..<70_000).map { UInt8(truncatingIfNeeded: $0) }
    let compressed = PureZlib.compressStored(output)
    XCTAssertEqual(try PureZlib.decompress(compressed, outputLimit: output.count), output)
    for limit in [0, 65_535, output.count - 1] {
      XCTAssertThrowsError(try PureZlib.decompress(compressed, outputLimit: limit)) {
        XCTAssertEqual($0 as? PureInflateError, .outputLimitExceeded(limit: limit))
      }
    }
  }

  func testStoredLengthIsRejectedBeforeReadingOrAppendingPayload() {
    // A valid stored-block length of 65,535 followed by no payload. The
    // budget must fail first, rather than iterating until input truncation.
    XCTAssertThrowsError(
      try PureInflate.decompress([1, 255, 255, 0, 0], outputLimit: 5)
    ) {
      XCTAssertEqual($0 as? PureInflateError, .outputLimitExceeded(limit: 5))
    }
  }

  func testEmptyZeroAndInvalidBudgets() throws {
    let empty = PureZlib.compressStored([])
    XCTAssertEqual(try PureZlib.decompress(empty, outputLimit: 0), [])
    for limit in [-1, Int.min] {
      XCTAssertThrowsError(try PureZlib.decompress(empty, outputLimit: limit)) {
        XCTAssertEqual($0 as? PureInflateError, .invalidOutputLimit)
      }
      XCTAssertThrowsError(try PureInflate.decompress([], outputLimit: limit)) {
        XCTAssertEqual($0 as? PureInflateError, .invalidOutputLimit)
      }
    }
    XCTAssertEqual(try PureZlib.decompress(empty, outputLimit: Int.max), [])
  }

  func testInvalidStartingOffsetsFailWithoutIndexing() {
    for offset in [-1, Int.min, 1, Int.max] {
      XCTAssertThrowsError(try PureInflate.decompress([], startingAt: offset, outputLimit: 5)) {
        XCTAssertEqual($0 as? PureInflateError, .truncated)
      }
    }
  }
}

final class PNGInflateBoundaryTests: XCTestCase {
  func testSmallHeaderStopsStoredFixedAndDynamicOverExpansion() throws {
    let compressedStreams = [
      PureZlib.compressStored([UInt8](repeating: 0, count: 9)),
      [UInt8](try XCTUnwrap(Data(base64Encoded: "eNpzdBwFxAIAy55MLQ=="))),
      [UInt8](
        try XCTUnwrap(
          Data(
            base64Encoded:
              "eNrtyUsCQCAAQMF8I6UoIcn9b9klLN9sRzRt1w+jnGa1aLNat+0+HPG87vTkt3yC53me53me53n+p696ecHB"
          )
        )
      ),
    ]
    for compressed in compressedStreams {
      // Before the bound, all streams inflated fully and only then failed
      // invalidPixelData. A 1x1 RGBA header admits exactly five bytes.
      // Exercise that former unbounded call with at most 3,200 bytes to
      // prove these are valid streams that exceed their declared raster.
      XCTAssertGreaterThan(try PureZlib.decompress(compressed).count, 5)
      XCTAssertThrowsError(
        try PurePNGCodec.decode(png(width: 1, height: 1, colorType: 6, compressed: compressed))
      ) {
        XCTAssertEqual(
          $0 as? PurePNGError,
          .compressionError(String(describing: PureInflateError.outputLimitExceeded(limit: 5)))
        )
      }
    }
  }

  func testExactFilteredLengthAndUnderflowRetainPixelValidation() throws {
    let exact = png(
      width: 1, height: 1, colorType: 6,
      compressed: PureZlib.compressStored([0, 12, 34, 56, 255])
    )
    XCTAssertEqual(try PurePNGCodec.decode(exact).pixels, [12, 34, 56, 255])
    let short = png(
      width: 1, height: 1, colorType: 6,
      compressed: PureZlib.compressStored([0, 12, 34, 56])
    )
    XCTAssertThrowsError(try PurePNGCodec.decode(short)) {
      XCTAssertEqual(
        $0 as? PurePNGError, .invalidPixelData("expected 5 filtered bytes, found 4")
      )
    }
  }

  func testFilteredAndRGBASizesRejectOverflowBeforeDecompression() {
    // The pixel count fits a 64-bit Int in both cases. RGBA filtered data
    // overflows in the first; grayscale output expansion overflows in the
    // second even though its filtered-byte count is representable.
    for colorType: UInt8 in [6, 0] {
      let huge = png(
        width: 2_147_483_647, height: 2_147_483_647,
        colorType: colorType, compressed: [0]
      )
      XCTAssertThrowsError(try PurePNGCodec.decode(huge)) {
        XCTAssertEqual($0 as? PurePNGError, .dimensionLimitExceeded)
      }
    }
  }

  private func png(
    width: UInt32, height: UInt32, colorType: UInt8, compressed: [UInt8]
  ) -> [UInt8] {
    var result = PurePNGCodec.signature
    let header = bigEndian(width) + bigEndian(height) + [8, colorType, 0, 0, 0]
    for (type, payload) in [("IHDR", header), ("IDAT", compressed), ("IEND", [])] {
      let body = Array(type.utf8) + payload
      result += bigEndian(UInt32(payload.count)) + body + bigEndian(Checksums.crc32(body))
    }
    return result
  }

  private func bigEndian(_ value: UInt32) -> [UInt8] {
    [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) }
  }
}
