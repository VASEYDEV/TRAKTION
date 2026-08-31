import FixtureForgeKit
import Foundation
import TraktionDomain
import TraktionVision
import XCTest

/// Decoded-pixel parity between the platform `PNGCodec` and the pure-Swift
/// fallback codec. On Apple hosts this crosses ImageIO and the pure codec in
/// both directions; on other hosts `PNGCodec` is the pure codec behind the
/// file contract, so the tests pin that contract instead.
final class PNGCodecParityTests: XCTestCase {
  private func makeTemporaryFile(_ name: String) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "traktion-parity-\(UUID().uuidString)-\(name)"
    )
  }

  func testPlatformCodecDecodesPureEncoderOutput() throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let url = makeTemporaryFile("pure-encoded.png")
    defer { try? FileManager.default.removeItem(at: url) }

    try Data(PurePNGCodec.encode(fixture.source)).write(to: url)
    let decoded = try PNGCodec.decodeOpaqueRGBA8(from: url)
    XCTAssertEqual(decoded, fixture.source)
  }

  func testPureDecoderReadsPlatformEncoderOutput() throws {
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let url = makeTemporaryFile("platform-encoded.png")
    defer { try? FileManager.default.removeItem(at: url) }

    try PNGCodec.encodeOpaqueRGBA8(fixture.source, to: url)
    let decoded = try PurePNGCodec.decode([UInt8](try Data(contentsOf: url)))
    XCTAssertEqual(decoded, fixture.source)
  }

  func testBothPathsRejectTransparencyIdentically() throws {
    // CPython-encoded vectors: RGB+tRNS chunk, and RGBA with one alpha=200
    // pixel. Both must be refused as non-opaque by whatever codec backs
    // `PNGCodec` on this host.
    let vectors = [
      "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAIAAAASFvFNAAAABnRSTlMAAAAAABEEFidjAAAAHElEQVR42mNgYBDUYBAMYBBkYIgS1IgSDIgSBAARYAJlqev6NAAAAABJRU5ErkJggg==",
      "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAHElEQVR42mNgYBD8rwHEAUDMwBAF5EQJnggA0gBbNwgoZuq6JAAAAABJRU5ErkJggg==",
    ]
    for (index, base64) in vectors.enumerated() {
      let url = makeTemporaryFile("transparency-\(index).png")
      defer { try? FileManager.default.removeItem(at: url) }
      try Data(base64Encoded: base64)!.write(to: url)
      XCTAssertThrowsError(try PNGCodec.decodeOpaqueRGBA8(from: url)) { error in
        guard case PNGCodecError.unsupportedTransparency? = error as? PNGCodecError else {
          return XCTFail("vector \(index): expected unsupportedTransparency, got \(error)")
        }
      }
    }
  }

  func testFileContractErrorsAreIdenticalAcrossPlatforms() throws {
    let missing = makeTemporaryFile("missing.png")
    XCTAssertThrowsError(try PNGCodec.decodeOpaqueRGBA8(from: missing)) { error in
      guard case PNGCodecError.fileNotFound? = error as? PNGCodecError else {
        return XCTFail("expected fileNotFound, got \(error)")
      }
    }

    let notPNG = makeTemporaryFile("not-a-png.png")
    defer { try? FileManager.default.removeItem(at: notPNG) }
    try Data([1, 2, 3, 4]).write(to: notPNG)
    XCTAssertThrowsError(try PNGCodec.decodeOpaqueRGBA8(from: notPNG)) { error in
      guard case PNGCodecError.unsupportedFormat? = error as? PNGCodecError else {
        return XCTFail("expected unsupportedFormat, got \(error)")
      }
    }

    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let existing = makeTemporaryFile("existing.png")
    defer { try? FileManager.default.removeItem(at: existing) }
    try Data([0]).write(to: existing)
    XCTAssertThrowsError(try PNGCodec.encodeOpaqueRGBA8(fixture.source, to: existing)) { error in
      guard case PNGCodecError.outputExists? = error as? PNGCodecError else {
        return XCTFail("expected outputExists, got \(error)")
      }
    }
  }
}
