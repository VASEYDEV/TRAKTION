public enum RasterImageError: Error, Equatable, Sendable {
  case invalidDimensions(width: Int, height: Int)
  case byteCountOverflow(width: Int, height: Int)
  case pixelCountMismatch(expected: Int, actual: Int)
}

public struct RasterImage: Equatable, Sendable {
  public static let channelsPerPixel = 4

  public let width: Int
  public let height: Int
  public let pixels: [UInt8]

  public init(width: Int, height: Int, pixels: [UInt8]) throws {
    guard width > 0, height > 0 else {
      throw RasterImageError.invalidDimensions(width: width, height: height)
    }

    let (pixelCount, pixelOverflow) = width.multipliedReportingOverflow(by: height)
    let (expectedByteCount, byteOverflow) = pixelCount.multipliedReportingOverflow(
      by: Self.channelsPerPixel
    )
    guard !pixelOverflow, !byteOverflow else {
      throw RasterImageError.byteCountOverflow(width: width, height: height)
    }
    guard pixels.count == expectedByteCount else {
      throw RasterImageError.pixelCountMismatch(
        expected: expectedByteCount,
        actual: pixels.count
      )
    }

    self.width = width
    self.height = height
    self.pixels = pixels
  }

  public var rowByteCount: Int {
    width * Self.channelsPerPixel
  }

  public func byteOffset(x: Int, y: Int) -> Int {
    (y * rowByteCount) + (x * Self.channelsPerPixel)
  }
}
