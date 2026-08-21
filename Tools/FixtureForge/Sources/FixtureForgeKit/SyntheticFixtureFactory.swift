import Foundation
import TraktionDomain

public struct SyntheticFixture: Equatable, Sendable {
  public let name: String
  public let source: RasterImage
  public let captures: [CaptureAsset]
  public let sourceOrigins: [Int]
  public let expectedOverlaps: [Int]

  public init(
    name: String,
    source: RasterImage,
    captures: [CaptureAsset],
    sourceOrigins: [Int],
    expectedOverlaps: [Int]
  ) {
    self.name = name
    self.source = source
    self.captures = captures
    self.sourceOrigins = sourceOrigins
    self.expectedOverlaps = expectedOverlaps
  }

  public var sequence: CaptureSequence {
    CaptureSequence(captures: captures)
  }
}

public enum SyntheticFixtureFactory {
  public static func baseline() throws -> SyntheticFixture {
    try verticalSequence(
      name: "baseline-three-capture",
      width: 64,
      sourceHeight: 240,
      viewportHeight: 96,
      origins: [0, 72, 144],
      seed: 0x5452_414B
    )
  }

  public static func exactTwoCapture() throws -> SyntheticFixture {
    try verticalSequence(
      name: "exact-two-capture",
      width: 48,
      sourceHeight: 168,
      viewportHeight: 96,
      origins: [0, 72],
      seed: 0x4558_4143
    )
  }

  public static func repeatedRows() throws -> SyntheticFixture {
    try verticalSequence(
      name: "repeated-looking-rows",
      width: 72,
      sourceHeight: 240,
      viewportHeight: 112,
      origins: [0, 64, 128],
      seed: 0x524F_5753,
      repeatedRows: true
    )
  }

  public static func large() throws -> SyntheticFixture {
    try verticalSequence(
      name: "large-performance",
      width: 160,
      sourceHeight: 840,
      viewportHeight: 360,
      origins: [0, 240, 480],
      seed: 0x5045_5246
    )
  }

  public static func unrelatedPair() throws -> CaptureSequence {
    let first = try document(width: 48, height: 96, seed: 1)
    let second = try document(width: 48, height: 96, seed: 9_999)
    return CaptureSequence(captures: [
      CaptureAsset(id: "unrelated-001", sourceName: "unrelated-001.png", image: first),
      CaptureAsset(id: "unrelated-002", sourceName: "unrelated-002.png", image: second),
    ])
  }

  public static func widthMismatchPair() throws -> CaptureSequence {
    let first = try document(width: 48, height: 96, seed: 10)
    let second = try document(width: 52, height: 96, seed: 11)
    return CaptureSequence(captures: [
      CaptureAsset(id: "width-001", sourceName: "width-001.png", image: first),
      CaptureAsset(id: "width-002", sourceName: "width-002.png", image: second),
    ])
  }

  public static func duplicatePair() throws -> CaptureSequence {
    let image = try document(width: 48, height: 96, seed: 21)
    return CaptureSequence(captures: [
      CaptureAsset(id: "duplicate-001", sourceName: "duplicate-001.png", image: image),
      CaptureAsset(id: "duplicate-002", sourceName: "duplicate-002.png", image: image),
    ])
  }

  public static func document(
    width: Int,
    height: Int,
    seed: UInt64,
    repeatedRows: Bool = false
  ) throws -> RasterImage {
    var pixels = [UInt8](
      repeating: 255,
      count: width * height * RasterImage.channelsPerPixel
    )

    for y in 0..<height {
      let visualRow = repeatedRows ? y % 18 : y
      let section = (visualRow / 24) % 4
      let uniqueBand = y / 18

      for x in 0..<width {
        let offset = ((y * width) + x) * RasterImage.channelsPerPixel
        let margin = max(4, width / 12)
        let inTextLine = x >= margin
          && x < width - margin
          && (visualRow % 12 == 4 || visualRow % 12 == 5)
        let inRule = visualRow % 29 == 0
        let inMarker = repeatedRows && x < 3 && (uniqueBand & 1) == 1
        let noise = UInt8(
          truncatingIfNeeded: seed
            &+ UInt64(x &* 31)
            &+ UInt64(y &* 17)
        )

        let red: UInt8
        let green: UInt8
        let blue: UInt8
        if inMarker {
          red = UInt8(truncatingIfNeeded: uniqueBand &* 37)
          green = UInt8(truncatingIfNeeded: uniqueBand &* 71)
          blue = UInt8(truncatingIfNeeded: uniqueBand &* 109)
        } else if inRule {
          red = 24
          green = 42
          blue = 52
        } else if inTextLine {
          red = 34 + UInt8(section * 8)
          green = 44 + UInt8(section * 7)
          blue = 58 + UInt8(section * 5)
        } else {
          red = 224 &+ (noise % 23)
          green = 226 &+ ((noise &* 3) % 21)
          blue = 229 &+ ((noise &* 5) % 18)
        }

        pixels[offset] = red
        pixels[offset + 1] = green
        pixels[offset + 2] = blue
        pixels[offset + 3] = 255
      }
    }
    return try RasterImage(width: width, height: height, pixels: pixels)
  }
}

private extension SyntheticFixtureFactory {
  static func verticalSequence(
    name: String,
    width: Int,
    sourceHeight: Int,
    viewportHeight: Int,
    origins: [Int],
    seed: UInt64,
    repeatedRows: Bool = false
  ) throws -> SyntheticFixture {
    let source = try document(
      width: width,
      height: sourceHeight,
      seed: seed,
      repeatedRows: repeatedRows
    )
    let captures = try origins.enumerated().map { index, origin in
      CaptureAsset(
        id: CaptureID(String(format: "capture-%03d", index + 1)),
        sourceName: String(format: "capture-%03d.png", index + 1),
        image: try crop(
          image: source,
          startRow: origin,
          rowCount: viewportHeight
        )
      )
    }
    let overlaps = origins.indices.dropFirst().map { index in
      origins[index - 1] + viewportHeight - origins[index]
    }
    return SyntheticFixture(
      name: name,
      source: source,
      captures: captures,
      sourceOrigins: origins,
      expectedOverlaps: overlaps
    )
  }

  static func crop(
    image: RasterImage,
    startRow: Int,
    rowCount: Int
  ) throws -> RasterImage {
    precondition(startRow >= 0 && startRow + rowCount <= image.height)
    let start = startRow * image.rowByteCount
    let end = (startRow + rowCount) * image.rowByteCount
    return try RasterImage(
      width: image.width,
      height: rowCount,
      pixels: Array(image.pixels[start..<end])
    )
  }
}
