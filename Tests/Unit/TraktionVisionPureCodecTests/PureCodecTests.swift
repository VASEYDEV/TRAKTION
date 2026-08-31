import Foundation
import TraktionDomain
import XCTest

@testable import TraktionVision

// Vectors marked "CPython" were generated once with CPython's zlib and are
// embedded as base64, proving the decoder against an independent DEFLATE
// implementation without a test-time dependency
// (docs/notes/2026-08-31-foundation-review-and-adaptation.md).

final class ChecksumTests: XCTestCase {
  func testReferenceVectors() {
    XCTAssertEqual(Checksums.crc32(Array("123456789".utf8)), 0xcbf4_3926)
    XCTAssertEqual(Checksums.crc32([]), 0)
    XCTAssertEqual(Checksums.adler32(Array("Wikipedia".utf8)), 0x11e6_0398)
    XCTAssertEqual(Checksums.adler32([]), 1)
  }
}

final class PureZlibTests: XCTestCase {
  private let repetitiveTextZlib =
    "eNoLCXL0DvH091MoSk3OzysuKSpNLilWKC4tKMjJTE1RKMssLk3MUUgty0xJzUtO1VMIGVU/qn5U/aj6UfWj6kfVU6weAM3Awg8="
  private let patternBytesZlib =
    "eJxj5hZV1LcPTK2evPbkcx69oIoFp75pRnbv/2qUs+KZdu7G7y59t3Rrz2vUXTOd+D5km3zr25gT1quVpgl2crSwt/NNkl1qciD4cZXwSrcHjSpHskV2pYsdKtW6MzWA93iHt8Cl2WnGTOcWlvmqMd7cMbMm0cNQhvPzk+tnDu/ZvmXzlu17Dp+5/uQzp4yhR2LNzB03GdV8yxaeYzJOm31JwLvjOG/A1DtapYfE0neJZB9RaXzgtlK46nHwAZOlspP42tlbODoFpymttj4R87ZVflvI+4mm1+o0ztfq3upz+b4xV/vZihyjr/u7IzW/nVpQEaTH8/zk2snVqYH2+oqi3Mw/vnz69OUH86jXR70+6vVRr496fdTro14f9fqo10e9Pur1Ua+Pen3U6yPF6wDLoa6V"
  private let tinyZlib = "eNpLTEoGAAJNASc="

  private func bytes(fromBase64 string: String) -> [UInt8] {
    [UInt8](Data(base64Encoded: string)!)
  }

  func testDecompressesRealZlibStreams() throws {
    // CPython zlib output at levels 9 and 6 (dynamic and fixed Huffman).
    let text = Array(
      String(repeating: "TRAKTION reconstructs supplied visual evidence. ", count: 40).utf8
    )
    XCTAssertEqual(try PureZlib.decompress(bytes(fromBase64: repetitiveTextZlib)), text)

    var pattern = [UInt8]()
    for index in 0..<4096 {
      pattern.append(UInt8((index * index + 7 * index + 3) % 251))
    }
    XCTAssertEqual(try PureZlib.decompress(bytes(fromBase64: patternBytesZlib)), pattern)

    XCTAssertEqual(try PureZlib.decompress(bytes(fromBase64: tinyZlib)), Array("abc".utf8))
  }

  func testStoredRoundTripIncludingMultiBlockPayloads() throws {
    var large = [UInt8]()
    for index in 0..<70_000 {  // more than one 64 KiB stored block
      large.append(UInt8(truncatingIfNeeded: index &* 31 &+ 7))
    }
    let payloads: [[UInt8]] = [[], [42], Array("short payload".utf8), large]
    for payload in payloads {
      XCTAssertEqual(try PureZlib.decompress(PureZlib.compressStored(payload)), payload)
    }
  }

  func testCorruptedStreamsFailTyped() {
    var corrupted = bytes(fromBase64: tinyZlib)
    corrupted[corrupted.count - 1] ^= 0xff
    XCTAssertThrowsError(try PureZlib.decompress(corrupted))

    XCTAssertThrowsError(try PureZlib.decompress([0x00, 0x00, 0, 0, 0, 0])) {
      XCTAssertEqual($0 as? PureInflateError, .invalidZlibHeader)
    }
    XCTAssertThrowsError(try PureZlib.decompress([0x78])) {
      XCTAssertEqual($0 as? PureInflateError, .truncated)
    }
  }
}

final class PurePNGCodecTests: XCTestCase {
  /// CPython-encoded 13x7 RGB with an ancillary tEXt chunk;
  /// pixel (x,y) = ((x*17+y*29)%256, (x*3)%256, (y*5)%256).
  private let interopPNG =
    "iVBORw0KGgoAAAANSUhEUgAAAA0AAAAHCAIAAABcElBNAAAAD3RFWHRDb21tZW50AGludGVyb3DG6cWAAAABD0lEQVR42gXBMSj4QRQA4KfrLnedXq73q3tdXh1nMTAow9/AoAwMFjEwWMRgkRKDRUoWKSlZpKQkJSUlKSkpSUnJIiUli5Qshv/3AQDUK2g00G6hx8MgwniA2QqWI2wm2Bc4y3BbABpAtyrdZfSA1WNeT6NeDHq90rtRnyR9Lfop64+i4R+4PuVGjJuybsG7VXTbwR1V7jK6h+TexP1kZ4qDIcAJhXMGVyxueTxAPA94V+FLxK+ENYIhY1NBmAFaUrRhaM/SqacbpOdAnxX9RapLJEJtmboLwRrwjuJjw1eWHz2/I/8Grq2YI7ck7hTuzzxaGA5BLpTcG3m18u1FoVCQ5ko6ovQmGRaZzDJf5D+aRTjrjei+0QAAAABJRU5ErkJggg=="
  /// The same image with rows filtered Sub/Up/Average/Paeth cycling per row.
  private let filteredPNG =
    "iVBORw0KGgoAAAANSUhEUgAAAA0AAAAHCAIAAABcElBNAAAAOUlEQVR42mNkYGAQZCaMmGQZWIlBzDoMHOJMzAQRC1CtINBqvEiWgYGxhEGEqu5LYxBCc8p0bO4DAFNtCrMi1OQgAAAAAElFTkSuQmCC"
  /// CPython-encoded 3x2 RGB with a tRNS chunk: transparency must be rejected.
  private let trnsRGBPNG =
    "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAIAAAASFvFNAAAABnRSTlMAAAAAABEEFidjAAAAHElEQVR42mNgYBDUYBAMYBBkYIgS1IgSDIgSBAARYAJlqev6NAAAAABJRU5ErkJggg=="
  /// CPython-encoded 3x2 RGBA with one alpha=200 pixel: must be rejected.
  private let alphaRGBAPNG =
    "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAHElEQVR42mNgYBD8rwHEAUDMwBAF5EQJnggA0gBbNwgoZuq6JAAAAABJRU5ErkJggg=="

  private func bytes(fromBase64 string: String) -> [UInt8] {
    [UInt8](Data(base64Encoded: string)!)
  }

  private func interopExpected() throws -> RasterImage {
    var pixels = [UInt8]()
    for y in 0..<7 {
      for x in 0..<13 {
        pixels.append(UInt8((x * 17 + y * 29) % 256))
        pixels.append(UInt8((x * 3) % 256))
        pixels.append(UInt8((y * 5) % 256))
        pixels.append(255)
      }
    }
    return try RasterImage(width: 13, height: 7, pixels: pixels)
  }

  func testRoundTripPreservesPixelsAndIsDeterministic() throws {
    var pixels = [UInt8]()
    for y in 0..<13 {
      for x in 0..<21 {
        pixels.append(UInt8((x * 7 + y * 13) % 256))
        pixels.append(UInt8((x * 29) % 256))
        pixels.append(UInt8((y * 31) % 256))
        pixels.append(255)
      }
    }
    let image = try RasterImage(width: 21, height: 13, pixels: pixels)
    let encoded = PurePNGCodec.encode(image)
    XCTAssertEqual(encoded, PurePNGCodec.encode(image))
    XCTAssertEqual(try PurePNGCodec.decode(encoded), image)
  }

  func testDecodesIndependentlyEncodedRGBIgnoringAncillaryChunks() throws {
    XCTAssertEqual(try PurePNGCodec.decode(bytes(fromBase64: interopPNG)), try interopExpected())
  }

  func testReconstructsSubUpAverageAndPaethFilteredRows() throws {
    XCTAssertEqual(try PurePNGCodec.decode(bytes(fromBase64: filteredPNG)), try interopExpected())
  }

  func testDecodesGrayscaleToOpaqueRGBA() throws {
    let base64 =
      "iVBORw0KGgoAAAANSUhEUgAAAAQAAAADCAAAAACRn/EaAAAAF0lEQVR42mNgMEqZxiAX0LSFwSZvwSUAHVsE7Ve2/OQAAAAASUVORK5CYII="
    let decoded = try PurePNGCodec.decode(bytes(fromBase64: base64))
    XCTAssertEqual(decoded.width, 4)
    XCTAssertEqual(decoded.height, 3)
    for y in 0..<3 {
      for x in 0..<4 {
        let value = UInt8((x * 50 + y * 30) % 256)
        let offset = decoded.byteOffset(x: x, y: y)
        XCTAssertEqual(decoded.pixels[offset], value)
        XCTAssertEqual(decoded.pixels[offset + 1], value)
        XCTAssertEqual(decoded.pixels[offset + 2], value)
        XCTAssertEqual(decoded.pixels[offset + 3], 255)
      }
    }
  }

  func testRejectsTransparencyInBothForms() {
    XCTAssertThrowsError(try PurePNGCodec.decode(bytes(fromBase64: trnsRGBPNG))) {
      XCTAssertEqual($0 as? PurePNGError, .nonOpaque)
    }
    XCTAssertThrowsError(try PurePNGCodec.decode(bytes(fromBase64: alphaRGBAPNG))) {
      XCTAssertEqual($0 as? PurePNGError, .nonOpaque)
    }
  }

  func testRejectsNonPNGTruncatedAndCorruptedInputTyped() {
    XCTAssertThrowsError(try PurePNGCodec.decode([0, 1, 2, 3])) {
      XCTAssertEqual($0 as? PurePNGError, .notAPNG)
    }

    let valid = bytes(fromBase64: interopPNG)
    XCTAssertThrowsError(try PurePNGCodec.decode(Array(valid.dropLast(5)))) {
      XCTAssertEqual($0 as? PurePNGError, .truncated)
    }

    var corrupted = valid
    corrupted[corrupted.count - 1] ^= 0xff  // IEND CRC
    XCTAssertThrowsError(try PurePNGCodec.decode(corrupted)) {
      XCTAssertEqual($0 as? PurePNGError, .checksumMismatch(chunkType: "IEND"))
    }
  }

  func testEnforcesTheDimensionLimitFromTheHeader() {
    let valid = bytes(fromBase64: interopPNG)
    XCTAssertThrowsError(try PurePNGCodec.decode(valid, maximumPixelCount: 13 * 7 - 1)) {
      XCTAssertEqual($0 as? PurePNGError, .dimensionLimitExceeded)
    }
    XCTAssertNoThrow(try PurePNGCodec.decode(valid, maximumPixelCount: 13 * 7))
  }

  func testRejectsUnsupportedBitDepthInsteadOfApproximating() {
    // Rebuild the interop header with bit depth 16 and a fixed-up CRC.
    var png = bytes(fromBase64: interopPNG)
    png[24] = 16  // IHDR bit-depth byte
    let crc = Checksums.crc32(png[12..<29])
    png[29] = UInt8(truncatingIfNeeded: crc >> 24)
    png[30] = UInt8(truncatingIfNeeded: crc >> 16)
    png[31] = UInt8(truncatingIfNeeded: crc >> 8)
    png[32] = UInt8(truncatingIfNeeded: crc)
    XCTAssertThrowsError(try PurePNGCodec.decode(png)) { error in
      guard case PurePNGError.unsupportedFormat? = error as? PurePNGError else {
        return XCTFail("expected unsupportedFormat, got \(error)")
      }
    }
  }
}
