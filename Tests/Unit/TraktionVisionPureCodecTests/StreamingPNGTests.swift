import Foundation
@testable import TraktionVision
import XCTest

final class StreamingPNGTests: XCTestCase {
  func testIndependentPixelsAcrossStoredBlockBoundariesAndPartialBlocks() throws {
    // Exact 65,535 filtered bytes, adjacent sizes, and rows larger than a block.
    for (width, height) in [(1, 1), (64, 255), (64, 256), (16_383, 1), (16_384, 3), (257, 5000)] {
      let sizes = try PNGStreamAdmission(width: width, height: height)
      var encoded = Data(), requested = [Int](), largest = 0
      try PNGCodec.streamOpaqueRGBA8(sizes, row: { y in
        requested.append(y)
        return (0..<width).flatMap { x in [UInt8(truncatingIfNeeded: x), UInt8(truncatingIfNeeded: y), UInt8(truncatingIfNeeded: x ^ y), 255] }
      }, write: { largest = max(largest, $0.count); encoded.append($0) })
      XCTAssertEqual(requested, Array(0..<height))
      XCTAssertLessThanOrEqual(largest, 65_552)
      XCTAssertEqual(encoded.count, sizes.encodedBytes)
      let decoded = try PurePNGCodec.decode(Array(encoded), maximumPixelCount: PNGStreamAdmission.maximumPixels)
      XCTAssertEqual(decoded.width, width); XCTAssertEqual(decoded.height, height)
      for y in 0..<height { for x in 0..<width {
        let i = (y * width + x) * 4
        XCTAssertEqual(Array(decoded.pixels[i..<i + 4]), [UInt8(truncatingIfNeeded: x), UInt8(truncatingIfNeeded: y), UInt8(truncatingIfNeeded: x ^ y), 255])
      } }
      if width * height <= PNGCodec.maximumPixelCount {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        try encoded.write(to: url)
        XCTAssertEqual(try PNGCodec.decodeOpaqueRGBA8(from: url), decoded)
      }
    }
  }

  func testLargeExportHasSeparateDecoderAdmission() throws {
    let sizes = try PNGStreamAdmission(width: 4096, height: 4097)
    XCTAssertGreaterThan(sizes.width * sizes.height, PNGCodec.maximumPixelCount)
    var encoded = Data(), reads = 0, largest = 0
    let row = [UInt8](repeating: 255, count: sizes.rowBytes)
    try PNGCodec.streamOpaqueRGBA8(sizes, row: { _ in reads += 1; return row }, write: {
      largest = max(largest, $0.count); encoded.append($0)
    })
    XCTAssertEqual(reads, 4097); XCTAssertLessThanOrEqual(largest, 65_552)
    XCTAssertEqual(encoded.count, sizes.encodedBytes)
    XCTAssertThrowsError(try PurePNGCodec.decode(Array(encoded), maximumPixelCount: PNGCodec.maximumPixelCount))
    let decoded = try PurePNGCodec.decode(Array(encoded), maximumPixelCount: PNGStreamAdmission.maximumPixels)
    XCTAssertEqual(decoded.width, 4096); XCTAssertEqual(decoded.height, 4097)
    XCTAssertTrue(decoded.pixels.allSatisfy { $0 == 255 })
  }

  func testAdmissionOverflowAndWorkingBudgetRefuseBeforeIO() throws {
    for (w, h) in [(0, 1), (-1, 2), (Int.max, 2), (2, Int.max), (262_145, 1), (8192, 8193)] {
      XCTAssertThrowsError(try PNGStreamAdmission(width: w, height: h)) {
        XCTAssertEqual($0 as? PNGStreamFailure, .resourceLimit)
      }
    }
    XCTAssertThrowsError(try PNGStreamAdmission(width: 1, height: 1, retainedBytes: Int.max))
    XCTAssertThrowsError(try PNGStreamAdmission(width: 1, height: 1, retainedBytes: -1))
    let exact = try PNGStreamAdmission(width: 1, height: 1)
    XCTAssertNoThrow(try PNGStreamAdmission(width: 1, height: 1, maximumWorkingBytes: exact.workingBytes))
    XCTAssertThrowsError(try PNGStreamAdmission(width: 1, height: 1, maximumWorkingBytes: exact.workingBytes - 1))
    XCTAssertEqual(PNGCodec.maximumPixelCount, 16_777_216)
  }

  func testMalformedRowsTransparencyCancellationAndSinkFailure() throws {
    let sizes = try PNGStreamAdmission(width: 1, height: 2)
    let malformed: [[UInt8]] = [[], [1, 2, 3], [1, 2, 3, 255, 0], [1, 2, 3, 0]]
    for pixels in malformed {
      XCTAssertThrowsError(try PNGCodec.streamOpaqueRGBA8(sizes, row: { _ in pixels }, write: { _ in })) {
        XCTAssertEqual($0 as? PNGStreamFailure, pixels.count == 4 ? .nonOpaque : .malformedRow)
      }
    }
    var reads = 0, writes = 0
    XCTAssertThrowsError(try PNGCodec.streamOpaqueRGBA8(sizes, isCancelled: { true }, row: { _ in reads += 1; return [] }, write: { _ in writes += 1 }))
    XCTAssertEqual(reads, 0); XCTAssertEqual(writes, 0)
    enum Sink: Error { case failed }
    XCTAssertThrowsError(try PNGCodec.streamOpaqueRGBA8(sizes, row: { _ in [1, 2, 3, 255] }, write: { _ in
      writes += 1; if writes == 4 { throw Sink.failed }
    })) { XCTAssertTrue($0 is Sink) }
    XCTAssertEqual(writes, 4)
    var cancelled = false
    XCTAssertThrowsError(try PNGCodec.streamOpaqueRGBA8(sizes, isCancelled: { cancelled }, row: { _ in
      cancelled = true; return [1, 2, 3, 255]
    }, write: { _ in })) { XCTAssertEqual($0 as? PNGStreamFailure, .cancelled) }
  }
}
