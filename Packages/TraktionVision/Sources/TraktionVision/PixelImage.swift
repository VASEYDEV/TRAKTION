import Foundation
import TraktionDomain

public struct PixelImage: Equatable, Sendable {
  public let width: Int
  public let height: Int
  public var rgba: [UInt8]

  public init(width: Int, height: Int, rgba: [UInt8]) {
    precondition(width > 0 && height > 0 && rgba.count == width * height * 4)
    self.width = width
    self.height = height
    self.rgba = rgba
  }

  public func rows(_ range: Range<Int>) -> ArraySlice<UInt8> {
    rgba[(range.lowerBound * width * 4)..<(range.upperBound * width * 4)]
  }
}
