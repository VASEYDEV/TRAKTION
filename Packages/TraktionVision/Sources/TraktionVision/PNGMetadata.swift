import Foundation

/// Validated static PNG structure and dimensions, obtained without decoding pixels.
public struct PNGMetadata: Equatable, Sendable {
  public let width: Int
  public let height: Int
  public let pixelCount: Int
  public let encodedByteCount: Int

  /// Streams chunk data in at most 64 KiB blocks. Checks CRCs, structural framing,
  /// animation markers and IHDR limits before a platform decoder can allocate a raster.
  /// Call on an owned snapshot; use PNGImportService for external security-scoped URLs.
  public static func inspect(
    from url: URL,
    maximumEncodedBytes: Int = 67_108_864,
    isCancelled: @Sendable () -> Bool = { false }
  ) throws -> PNGMetadata {
    let name = importName(url)
    guard url.isFileURL else { throw PNGImportFailure.invalidFile(name) }
    do {
      try checkCancellation(isCancelled)
      let handle = try FileHandle(forReadingFrom: url)
      defer { try? handle.close() }
      let byteCount = try handle.seekToEnd()
      guard maximumEncodedBytes > 0, byteCount <= UInt64(maximumEncodedBytes) else {
        throw PNGImportFailure.resourceLimitExceeded("Encoded file allowance exceeded by \(name).")
      }
      try handle.seek(toOffset: 0)
      guard try read(handle, count: 8, name: name) == Data([137, 80, 78, 71, 13, 10, 26, 10]) else {
        throw PNGImportFailure.codec(.unsupportedFormat(name))
      }

      var position: UInt64 = 8
      var dimensions: (width: Int, height: Int, pixels: Int)?
      var hasImageData = false
      var endedImageData = false
      var hasPalette = false
      var colorType: UInt8 = 0
      var depth: UInt8 = 0
      while position < byteCount {
        try checkCancellation(isCancelled)
        guard byteCount - position >= 12 else { throw corrupt(name) }
        let prefix = try read(handle, count: 8, name: name)
        let length = Int(bigEndian(prefix, offset: 0))
        let typeBytes = Array(prefix[4..<8])
        guard length <= Int32.max,
          typeBytes.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) }),
          (65...90).contains(typeBytes[2]),
          UInt64(length) + 12 <= byteCount - position
        else { throw corrupt(name) }
        let type = String(decoding: typeBytes, as: UTF8.self)
        if dimensions == nil, type != "IHDR" { throw corrupt(name) }
        if ["acTL", "fcTL", "fdAT"].contains(type) {
          throw PNGImportFailure.codec(.unsupportedFormat("\(name) (animated PNG)"))
        }
        if type == "tRNS" {
          throw PNGImportFailure.codec(.unsupportedTransparency(name))
        }
        if (65...90).contains(typeBytes[0]), !["IHDR", "PLTE", "IDAT", "IEND"].contains(type) {
          throw PNGImportFailure.codec(.unsupportedFormat(name))
        }
        guard type != "IHDR" || (dimensions == nil && length == 13) else { throw corrupt(name) }
        guard type != "IEND" || length == 0 else { throw corrupt(name) }

        var crc: UInt32 = 0xffff_ffff
        updateCRC(&crc, bytes: typeBytes)
        var remaining = length
        var header = Data()
        while remaining > 0 {
          try checkCancellation(isCancelled)
          let data = try read(handle, count: min(65_536, remaining), name: name)
          updateCRC(&crc, bytes: data)
          if type == "IHDR" { header = data }
          remaining -= data.count
        }
        let expectedCRC = bigEndian(try read(handle, count: 4, name: name), offset: 0)
        guard crc ^ 0xffff_ffff == expectedCRC else { throw corrupt(name) }
        position += UInt64(length) + 12

        switch type {
        case "IHDR":
          let width = Int(bigEndian(header, offset: 0))
          let height = Int(bigEndian(header, offset: 4))
          let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
          guard width > 0, height > 0, width <= Int32.max, height <= Int32.max,
            !overflow, pixels <= PNGCodec.maximumPixelCount
          else { throw PNGImportFailure.codec(.resourceLimitExceeded(name)) }
          depth = header[8]
          colorType = header[9]
          let validDepth: Bool
          switch colorType {
          case 0: validDepth = [1, 2, 4, 8, 16].contains(depth)
          case 2, 4, 6: validDepth = [8, 16].contains(depth)
          case 3: validDepth = [1, 2, 4, 8].contains(depth)
          default: validDepth = false
          }
          guard validDepth, header[10] == 0, header[11] == 0, header[12] <= 1 else {
            throw PNGImportFailure.codec(.unsupportedFormat(name))
          }
          dimensions = (width, height, pixels)
        case "PLTE":
          guard !hasPalette, !hasImageData, colorType != 0, colorType != 4,
            length > 0, length <= 768, length.isMultiple(of: 3),
            colorType != 3 || length / 3 <= 1 << Int(depth)
          else { throw corrupt(name) }
          hasPalette = true
        case "IDAT":
          guard !endedImageData, colorType != 3 || hasPalette else { throw corrupt(name) }
          hasImageData = true
        case "IEND":
          guard hasImageData, position == byteCount, let dimensions else { throw corrupt(name) }
          return PNGMetadata(
            width: dimensions.width, height: dimensions.height,
            pixelCount: dimensions.pixels, encodedByteCount: Int(byteCount)
          )
        default:
          if hasImageData { endedImageData = true }
        }
      }
      throw corrupt(name)
    } catch let failure as PNGImportFailure {
      throw failure
    } catch {
      throw PNGImportFailure.fileAccess(name)
    }
  }

  private static func read(_ file: FileHandle, count: Int, name: String) throws -> Data {
    let data = try file.read(upToCount: count) ?? Data()
    guard data.count == count else { throw corrupt(name) }
    return data
  }

  private static func corrupt(_ name: String) -> PNGImportFailure {
    .codec(.decodeFailed(name))
  }

  private static func bigEndian(_ bytes: Data, offset: Int) -> UInt32 {
    UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
      | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
  }

  private static let crcTable: [UInt32] = (0..<256).map { index in
    var value = UInt32(index)
    for _ in 0..<8 {
      value = value & 1 == 1 ? (value >> 1) ^ 0xedb8_8320 : value >> 1
    }
    return value
  }

  private static func updateCRC<S: Sequence>(_ crc: inout UInt32, bytes: S) where S.Element == UInt8 {
    for byte in bytes { crc = crcTable[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8) }
  }
}
