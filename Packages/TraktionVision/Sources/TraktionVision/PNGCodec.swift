import Foundation
import TraktionDomain

public enum PNGCodecError: Error, Equatable, Sendable {
  case unsupportedPlatform
  case fileNotFound(String)
  case outputExists(String)
  case unsupportedFormat(String)
  case unsupportedTransparency(String)
  case resourceLimitExceeded(String)
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
    case .resourceLimitExceeded(let name):
      return "PNG dimensions exceed the Milestone 1 resource limit: \(name)"
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
    public static let maximumPixelCount = 16_777_216

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
      guard
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
          as? [CFString: Any],
        let widthNumber = properties[kCGImagePropertyPixelWidth] as? NSNumber,
        let heightNumber = properties[kCGImagePropertyPixelHeight] as? NSNumber
      else {
        throw PNGCodecError.decodeFailed(name)
      }
      try validateDimensions(
        width: widthNumber.intValue,
        height: heightNumber.intValue,
        name: name
      )
      guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw PNGCodecError.decodeFailed(name)
      }

      let width = image.width
      let height = image.height
      try validateDimensions(width: width, height: height, name: name)
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
          in: CGRect(
            x: 0,
            y: 0,
            width: CGFloat(width),
            height: CGFloat(height)
          )
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
      try validateDimensions(width: image.width, height: image.height, name: name)

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

    private static func validateDimensions(
      width: Int,
      height: Int,
      name: String
    ) throws {
      let (pixelCount, overflow) = width.multipliedReportingOverflow(by: height)
      guard width > 0,
        height > 0,
        !overflow,
        pixelCount <= maximumPixelCount
      else {
        throw PNGCodecError.resourceLimitExceeded(name)
      }
    }
  }
#else
  // Non-Apple fallback: the deterministic pure-Swift codec (docs/adr/ADR-011)
  // behind the identical contract — opaque input only, the same error cases,
  // and the same dimension limit. Decoded-pixel parity with the Apple path is
  // asserted by Tests/Integration/PNGCodecParityTests.swift.
  public enum PNGCodec {
    public static let isAvailable = true
    public static let maximumPixelCount = 16_777_216

    public static func decodeOpaqueRGBA8(from url: URL) throws -> RasterImage {
      let name = url.lastPathComponent
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw PNGCodecError.fileNotFound(name)
      }
      let bytes: [UInt8]
      do {
        bytes = [UInt8](try Data(contentsOf: url))
      } catch {
        throw PNGCodecError.decodeFailed(name)
      }
      do {
        return try PurePNGCodec.decode(bytes, maximumPixelCount: maximumPixelCount)
      } catch PurePNGError.notAPNG {
        throw PNGCodecError.unsupportedFormat(name)
      } catch let PurePNGError.unsupportedFormat(details) {
        throw PNGCodecError.unsupportedFormat("\(name) (\(details))")
      } catch PurePNGError.nonOpaque {
        throw PNGCodecError.unsupportedTransparency(name)
      } catch PurePNGError.dimensionLimitExceeded {
        throw PNGCodecError.resourceLimitExceeded(name)
      } catch {
        throw PNGCodecError.decodeFailed(name)
      }
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
      let (pixelCount, overflow) = image.width.multipliedReportingOverflow(by: image.height)
      guard !overflow, pixelCount <= maximumPixelCount else {
        throw PNGCodecError.resourceLimitExceeded(name)
      }

      do {
        try Data(PurePNGCodec.encode(image)).write(to: url, options: .withoutOverwriting)
      } catch {
        throw PNGCodecError.encodeFailed(name)
      }
    }
  }
#endif
