import Foundation

public struct CaptureID: RawRepresentable, Hashable, Codable, Sendable,
  CustomStringConvertible, ExpressibleByStringLiteral
{
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.rawValue = value
  }

  public var description: String {
    rawValue
  }
}

public struct CaptureAsset: Equatable, Sendable {
  public let id: CaptureID
  public let sourceName: String
  public let image: RasterImage
  /// Exact validated import bytes, retained independently from decoded pixels.
  public let originalPNG: Data?

  public init(id: CaptureID, sourceName: String, image: RasterImage, originalPNG: Data? = nil) {
    self.id = id
    self.sourceName = sourceName
    self.image = image
    self.originalPNG = originalPNG
  }
}

public struct CaptureSequence: Equatable, Sendable {
  public let captures: [CaptureAsset]

  public init(captures: [CaptureAsset]) {
    self.captures = captures
  }
}

public enum ReconstructionAxis: String, Hashable, Codable, Sendable {
  case vertical
  case horizontal
}
