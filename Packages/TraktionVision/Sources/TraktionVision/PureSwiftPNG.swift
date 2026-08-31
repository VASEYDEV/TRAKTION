import TraktionDomain

// Pure-Swift PNG codec used as the non-Apple fallback behind `PNGCodec`
// (docs/adr/ADR-011). Deterministic and dependency-free: identical input bytes
// produce identical output bytes on every platform. Decode supports what
// screenshots realistically use — 8-bit gray/RGB/RGBA, non-interlaced — and
// rejects everything else (including any transparency) with a typed error.
// Encode writes 8-bit RGBA with filter 0 and stored-block zlib; size is traded
// for byte determinism, and callers compare decoded pixels, never PNG bytes.

public enum PurePNGError: Error, Equatable, Sendable {
  case notAPNG
  case truncated
  case invalidStructure(String)
  case checksumMismatch(chunkType: String)
  case unsupportedFormat(String)
  case nonOpaque
  case dimensionLimitExceeded
  case invalidPixelData(String)
  case compressionError(String)
}

public enum PurePNGCodec {
  static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

  // MARK: - Encode

  public static func encode(_ image: RasterImage) -> [UInt8] {
    var raw = [UInt8]()
    raw.reserveCapacity(image.height * (1 + image.rowByteCount))
    for row in 0..<image.height {
      raw.append(0)  // filter type: None
      let start = row * image.rowByteCount
      raw.append(contentsOf: image.pixels[start..<(start + image.rowByteCount)])
    }

    var ihdr = [UInt8]()
    appendBigEndian(UInt32(image.width), to: &ihdr)
    appendBigEndian(UInt32(image.height), to: &ihdr)
    ihdr.append(contentsOf: [8, 6, 0, 0, 0])  // depth 8, RGBA, deflate, filter 0, no interlace

    var output = signature
    appendChunk(type: "IHDR", data: ihdr, to: &output)
    appendChunk(type: "IDAT", data: PureZlib.compressStored(raw), to: &output)
    appendChunk(type: "IEND", data: [], to: &output)
    return output
  }

  // MARK: - Decode

  /// Decodes an opaque PNG into RGBA8. Any transparency (an alpha sample
  /// below 255 or a tRNS chunk) throws `nonOpaque`; `maximumPixelCount` is
  /// enforced from the header before pixel data is inflated.
  public static func decode(
    _ bytes: [UInt8],
    maximumPixelCount: Int? = nil
  ) throws -> RasterImage {
    guard bytes.count >= signature.count, Array(bytes[0..<8]) == signature else {
      throw PurePNGError.notAPNG
    }

    var offset = 8
    var header: (width: Int, height: Int, colorType: Int)?
    var idat = [UInt8]()
    var sawEnd = false

    while offset < bytes.count, !sawEnd {
      guard offset + 8 <= bytes.count else { throw PurePNGError.truncated }
      let length = Int(readBigEndian(bytes, at: offset))
      let type = String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self)
      let dataStart = offset + 8
      guard dataStart + length + 4 <= bytes.count else { throw PurePNGError.truncated }
      let data = Array(bytes[dataStart..<(dataStart + length)])
      let declaredCRC = readBigEndian(bytes, at: dataStart + length)
      guard Checksums.crc32(bytes[(offset + 4)..<(dataStart + length)]) == declaredCRC else {
        throw PurePNGError.checksumMismatch(chunkType: type)
      }
      offset = dataStart + length + 4

      switch type {
      case "IHDR":
        guard header == nil else { throw PurePNGError.invalidStructure("duplicate IHDR") }
        guard data.count == 13 else {
          throw PurePNGError.invalidStructure("IHDR length \(data.count)")
        }
        let width = Int(readBigEndian(data, at: 0))
        let height = Int(readBigEndian(data, at: 4))
        let bitDepth = Int(data[8])
        let colorType = Int(data[9])
        guard data[10] == 0, data[11] == 0 else {
          throw PurePNGError.unsupportedFormat("nonstandard compression or filter method")
        }
        guard data[12] == 0 else {
          throw PurePNGError.unsupportedFormat("interlaced (Adam7) PNG")
        }
        guard bitDepth == 8 else {
          throw PurePNGError.unsupportedFormat("bit depth \(bitDepth); only 8 is supported")
        }
        guard colorType == 0 || colorType == 2 || colorType == 6 else {
          throw PurePNGError.unsupportedFormat(
            "color type \(colorType); supported: 0 (gray), 2 (RGB), 6 (RGBA)"
          )
        }
        guard width > 0, height > 0 else {
          throw PurePNGError.invalidStructure("empty image \(width)x\(height)")
        }
        let (pixelCount, overflow) = width.multipliedReportingOverflow(by: height)
        if overflow { throw PurePNGError.dimensionLimitExceeded }
        if let maximumPixelCount, pixelCount > maximumPixelCount {
          throw PurePNGError.dimensionLimitExceeded
        }
        header = (width, height, colorType)
      case "tRNS":
        // Milestone 1 requires opaque input; a transparency chunk on any
        // color type makes the image non-opaque.
        throw PurePNGError.nonOpaque
      case "IDAT":
        guard header != nil else { throw PurePNGError.invalidStructure("IDAT before IHDR") }
        idat.append(contentsOf: data)
      case "IEND":
        sawEnd = true
      default:
        continue  // ancillary chunks (tEXt, pHYs, ...) are ignored
      }
    }

    guard let header else { throw PurePNGError.invalidStructure("missing IHDR") }
    guard sawEnd else { throw PurePNGError.truncated }
    guard !idat.isEmpty else { throw PurePNGError.invalidStructure("missing IDAT") }

    let raw: [UInt8]
    do {
      raw = try PureZlib.decompress(idat)
    } catch {
      throw PurePNGError.compressionError(String(describing: error))
    }

    let channels = header.colorType == 6 ? 4 : (header.colorType == 2 ? 3 : 1)
    let rowBytes = header.width * channels
    guard raw.count == header.height * (1 + rowBytes) else {
      throw PurePNGError.invalidPixelData(
        "expected \(header.height * (1 + rowBytes)) filtered bytes, found \(raw.count)"
      )
    }

    let unfiltered = try unfilter(
      raw,
      height: header.height,
      rowBytes: rowBytes,
      bytesPerPixel: channels
    )

    var pixels: [UInt8]
    switch channels {
    case 4:
      pixels = unfiltered
      for alphaOffset in stride(from: 3, to: pixels.count, by: 4)
        where pixels[alphaOffset] != 255
      {
        throw PurePNGError.nonOpaque
      }
    case 3:
      pixels = [UInt8]()
      pixels.reserveCapacity(header.width * header.height * 4)
      var index = 0
      while index < unfiltered.count {
        pixels.append(unfiltered[index])
        pixels.append(unfiltered[index + 1])
        pixels.append(unfiltered[index + 2])
        pixels.append(255)
        index += 3
      }
    default:
      pixels = [UInt8]()
      pixels.reserveCapacity(header.width * header.height * 4)
      for value in unfiltered {
        pixels.append(value)
        pixels.append(value)
        pixels.append(value)
        pixels.append(255)
      }
    }

    do {
      return try RasterImage(width: header.width, height: header.height, pixels: pixels)
    } catch {
      throw PurePNGError.invalidPixelData(String(describing: error))
    }
  }

  // MARK: - Filters (RFC 2083 §6)

  private static func unfilter(
    _ raw: [UInt8],
    height: Int,
    rowBytes: Int,
    bytesPerPixel: Int
  ) throws -> [UInt8] {
    var output = [UInt8](repeating: 0, count: height * rowBytes)
    for row in 0..<height {
      let filterType = raw[row * (1 + rowBytes)]
      let rowStart = row * (1 + rowBytes) + 1
      let outStart = row * rowBytes
      let previousStart = outStart - rowBytes
      for index in 0..<rowBytes {
        let value = raw[rowStart + index]
        let left = index >= bytesPerPixel ? output[outStart + index - bytesPerPixel] : 0
        let up = row > 0 ? output[previousStart + index] : 0
        let upLeft = (row > 0 && index >= bytesPerPixel)
          ? output[previousStart + index - bytesPerPixel]
          : 0
        let reconstructed: UInt8
        switch filterType {
        case 0:
          reconstructed = value
        case 1:
          reconstructed = value &+ left
        case 2:
          reconstructed = value &+ up
        case 3:
          reconstructed = value &+ UInt8((Int(left) + Int(up)) / 2)
        case 4:
          reconstructed = value &+ paethPredictor(left, up, upLeft)
        default:
          throw PurePNGError.invalidPixelData("unknown filter type \(filterType) in row \(row)")
        }
        output[outStart + index] = reconstructed
      }
    }
    return output
  }

  private static func paethPredictor(_ a: UInt8, _ b: UInt8, _ c: UInt8) -> UInt8 {
    let p = Int(a) + Int(b) - Int(c)
    let pa = abs(p - Int(a))
    let pb = abs(p - Int(b))
    let pc = abs(p - Int(c))
    if pa <= pb && pa <= pc { return a }
    if pb <= pc { return b }
    return c
  }

  // MARK: - Chunk helpers

  private static func appendChunk(type: String, data: [UInt8], to output: inout [UInt8]) {
    appendBigEndian(UInt32(data.count), to: &output)
    let typeBytes = Array(type.utf8)
    output.append(contentsOf: typeBytes)
    output.append(contentsOf: data)
    appendBigEndian(Checksums.crc32(typeBytes + data), to: &output)
  }

  private static func appendBigEndian(_ value: UInt32, to output: inout [UInt8]) {
    output.append(UInt8(truncatingIfNeeded: value >> 24))
    output.append(UInt8(truncatingIfNeeded: value >> 16))
    output.append(UInt8(truncatingIfNeeded: value >> 8))
    output.append(UInt8(truncatingIfNeeded: value))
  }

  private static func readBigEndian(_ bytes: [UInt8], at offset: Int) -> UInt32 {
    UInt32(bytes[offset]) << 24
      | UInt32(bytes[offset + 1]) << 16
      | UInt32(bytes[offset + 2]) << 8
      | UInt32(bytes[offset + 3])
  }
}
