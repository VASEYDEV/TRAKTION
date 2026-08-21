import FixtureForgeKit
import Foundation
import TraktionVision
import XCTest

final class PNGCodecIntegrationTests: XCTestCase {
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
