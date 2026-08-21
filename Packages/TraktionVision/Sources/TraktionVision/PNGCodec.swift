import Foundation
import TraktionDomain

public enum PNGCodecError: Error, Equatable, Sendable {
  case unsupportedPlatform
  case fileNotFound(String)
  case outputExists(String)
  case unsupportedFormat(String)
  case unsupportedTransparency(String)
  case decodeFailed(String)
  case encodeFailed(String)
}

extension PNGCodecError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .unsupportedPlatform:
      return "PNG decoding and encoding require an Apple ImageIO runtime."
    case .fileNotFound(let name):
      return "PNG input does not exist: \(name)"
    case .outputExists(let name):
      return "Refusing to overwrite existing output: \(name)"
    case .unsupportedFormat(let name):
      return "Input is not a supported PNG: \(name)"
    case .unsupportedTransparency(let name):
      return "Milestone 1 requires opaque PNG input: \(name)"
    case .decodeFailed(let name):
      return "Could not decode PNG input: \(name)"
    case .encodeFailed(let name):
      return "Could not encode PNG output: \(name)"
    }
  }
}

#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
  import CoreGraphics
  import ImageIO
  import UniformTypeIdentifiers

  public enum PNGCodec {
    public static let isAvailable = true

    public static func decodeOpaqueRGBA8(from url: URL) throws -> RasterImage {
      let name = url.lastPathComponent
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw PNGCodecError.fileNotFound(name)
      }
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let sourceType = CGImageSourceGetType(source),
        UTType(sourceType as String)?.conforms(to: .png) == true
      else {
        throw PNGCodecError.unsupportedFormat(name)
      }
      guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw PNGCodecError.decodeFailed(name)
      }

      let width = image.width
      let height = image.height
      let (pixelCount, pixelOverflow) = width.multipliedReportingOverflow(by: height)
      let (byteCount, byteOverflow) = pixelCount.multipliedReportingOverflow(
        by: RasterImage.channelsPerPixel
      )
      guard width > 0, height > 0, !pixelOverflow, !byteOverflow else {
        throw PNGCodecError.decodeFailed(name)
      }

      var pixels = [UInt8](repeating: 0, count: byteCount)
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        ?? CGColorSpaceCreateDeviceRGB()
      let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        | CGImageAlphaInfo.premultipliedLast.rawValue
      let didDraw = pixels.withUnsafeMutableBytes { bytes -> Bool in
        guard let context = CGContext(
          data: bytes.baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width * RasterImage.channelsPerPixel,
          space: colorSpace,
          bitmapInfo: bitmapInfo
        ) else {
          return false
        }
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(
          image,
          in: CGRect(x: 0, y: 0, width: width, height: height)
        )
        return true
      }
      guard didDraw else {
        throw PNGCodecError.decodeFailed(name)
      }

      for alphaOffset in stride(from: 3, to: pixels.count, by: 4)
        where pixels[alphaOffset] != 255
      {
        throw PNGCodecError.unsupportedTransparency(name)
      }
      return try RasterImage(width: width, height: height, pixels: pixels)
    }

    public static func encodeOpaqueRGBA8(
      _ image: RasterImage,
      to url: URL
    ) throws {
      let name = url.lastPathComponent
      guard !FileManager.default.fileExists(atPath: url.path) else {
        throw PNGCodecError.outputExists(name)
      }
      for alphaOffset in stride(from: 3, to: image.pixels.count, by: 4)
        where image.pixels[alphaOffset] != 255
      {
        throw PNGCodecError.unsupportedTransparency(name)
      }

      let data = Data(image.pixels)
      guard let provider = CGDataProvider(data: data as CFData) else {
        throw PNGCodecError.encodeFailed(name)
      }
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        ?? CGColorSpaceCreateDeviceRGB()
      let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
        CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
      )
      guard let cgImage = CGImage(
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: image.rowByteCount,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      ),
        let destination = CGImageDestinationCreateWithURL(
          url as CFURL,
          UTType.png.identifier as CFString,
          1,
          nil
        )
      else {
        throw PNGCodecError.encodeFailed(name)
      }

      CGImageDestinationAddImage(destination, cgImage, nil)
      guard CGImageDestinationFinalize(destination) else {
        throw PNGCodecError.encodeFailed(name)
      }
    }
  }
#else
  public enum PNGCodec {
    public static let isAvailable = false

    public static func decodeOpaqueRGBA8(from url: URL) throws -> RasterImage {
      _ = url
      throw PNGCodecError.unsupportedPlatform
    }

    public static func encodeOpaqueRGBA8(
      _ image: RasterImage,
      to url: URL
    ) throws {
      _ = image
      _ = url
      throw PNGCodecError.unsupportedPlatform
    }
  }
#endif
