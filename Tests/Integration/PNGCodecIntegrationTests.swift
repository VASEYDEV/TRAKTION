import FixtureForgeKit
import Foundation
import TraktionDomain
import TraktionVision
import XCTest

final class PNGCodecIntegrationTests: XCTestCase {
  func testDecodeKnownAsymmetricPNGPreservesRowAndChannelOrder() throws {
    guard PNGCodec.isAvailable else {
      throw XCTSkip("Apple ImageIO is unavailable on this host.")
    }
    let encoded = Data(
      base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR42mP4z8DwHwyBNBAw/AcAR8oI+FuapL4AAAAASUVORK5CYII="
    )!
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(
      "traktion-asymmetric-\(UUID().uuidString).png"
    )
    defer { try? FileManager.default.removeItem(at: output) }
    try encoded.write(to: output, options: .atomic)

    let decoded = try PNGCodec.decodeOpaqueRGBA8(from: output)
    let expected = try RasterImage(
      width: 2,
      height: 2,
      pixels: [
        255, 0, 0, 255, 0, 255, 0, 255,
        0, 0, 255, 255, 255, 255, 0, 255,
      ]
    )

    XCTAssertEqual(decoded, expected)
  }

  func testOpaquePNGEncodeDecodePreservesPixels() throws {
    guard PNGCodec.isAvailable else {
      throw XCTSkip("Apple ImageIO is unavailable on this host.")
    }
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    let output = directory.appendingPathComponent("roundtrip.png")
    try PNGCodec.encodeOpaqueRGBA8(fixture.source, to: output)
    let decoded = try PNGCodec.decodeOpaqueRGBA8(from: output)

    XCTAssertEqual(decoded, fixture.source)
  }
}
