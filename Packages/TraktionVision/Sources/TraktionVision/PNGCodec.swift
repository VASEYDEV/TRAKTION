import CZlib
import Foundation
import TraktionDomain

public enum PNGCodec {
  private static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

  public static func decode(contentsOf url: URL) throws -> PixelImage {
    let data: Data
    do { data = try Data(contentsOf: url) } catch {
      throw ReconstructionFailure.invalidPNG(path: url.path, reason: error.localizedDescription)
    }
    let bytes = [UInt8](data)
    guard bytes.count >= 33, Array(bytes.prefix(8)) == signature else {
      throw ReconstructionFailure.invalidPNG(path: url.path, reason: "missing PNG signature")
    }
    var offset = 8
    var width = 0
    var height = 0
    var colorType: UInt8 = 0
    var compressed = [UInt8]()
    var sawHeader = false
    while offset + 12 <= bytes.count {
      let length = Int(readUInt32(bytes, offset))
      offset += 4
      guard offset + 8 + length <= bytes.count else {
        throw ReconstructionFailure.invalidPNG(path: url.path, reason: "truncated chunk")
      }
      let type = String(bytes: bytes[offset..<(offset + 4)], encoding: .ascii) ?? ""
      offset += 4
      let chunk = Array(bytes[offset..<(offset + length)])
      offset += length + 4
      if type == "IHDR" {
        guard chunk.count == 13 else {
          throw ReconstructionFailure.invalidPNG(path: url.path, reason: "invalid IHDR")
        }
        width = Int(readUInt32(chunk, 0))
        height = Int(readUInt32(chunk, 4))
        colorType = chunk[9]
        guard width > 0, height > 0, chunk[8] == 8, chunk[10] == 0, chunk[11] == 0, chunk[12] == 0
        else {
          throw ReconstructionFailure.unsupportedPNG(
            path: url.path, reason: "requires 8-bit, non-interlaced PNG")
        }
        sawHeader = true
      } else if type == "IDAT" {
        compressed += chunk
      } else if type == "IEND" {
        break
      }
    }
    guard sawHeader, !compressed.isEmpty else {
      throw ReconstructionFailure.invalidPNG(path: url.path, reason: "missing IHDR or IDAT")
    }
    let channels: Int
    switch colorType {
    case 0: channels = 1
    case 2: channels = 3
    case 4: channels = 2
    case 6: channels = 4
    default:
      throw ReconstructionFailure.unsupportedPNG(path: url.path, reason: "color type \(colorType)")
    }
    let stride = width * channels
    var inflated = [UInt8](repeating: 0, count: (stride + 1) * height)
    var inflatedSize = uLongf(inflated.count)
    let result = compressed.withUnsafeBytes { source in
      inflated.withUnsafeMutableBytes { destination in
        uncompress(
          destination.bindMemory(to: Bytef.self).baseAddress, &inflatedSize,
          source.bindMemory(to: Bytef.self).baseAddress, uLong(compressed.count))
      }
    }
    guard result == Z_OK, inflatedSize == inflated.count else {
      throw ReconstructionFailure.invalidPNG(
        path: url.path, reason: "zlib decompression failed (\(result))")
    }
    var raw = [UInt8](repeating: 0, count: stride * height)
    for y in 0..<height {
      let filter = inflated[y * (stride + 1)]
      guard filter <= 4 else {
        throw ReconstructionFailure.invalidPNG(path: url.path, reason: "unknown filter \(filter)")
      }
      for x in 0..<stride {
        let encoded = inflated[y * (stride + 1) + 1 + x]
        let left = x >= channels ? raw[y * stride + x - channels] : 0
        let above = y > 0 ? raw[(y - 1) * stride + x] : 0
        let upperLeft = y > 0 && x >= channels ? raw[(y - 1) * stride + x - channels] : 0
        let predictor: UInt8
        switch filter {
        case 0: predictor = 0
        case 1: predictor = left
        case 2: predictor = above
        case 3: predictor = UInt8((Int(left) + Int(above)) / 2)
        default: predictor = paeth(left, above, upperLeft)
        }
        raw[y * stride + x] = encoded &+ predictor
      }
    }
    var rgba = [UInt8]()
    rgba.reserveCapacity(width * height * 4)
    for index in Swift.stride(from: 0, to: raw.count, by: channels) {
      switch colorType {
      case 0: rgba += [raw[index], raw[index], raw[index], 255]
      case 2: rgba += [raw[index], raw[index + 1], raw[index + 2], 255]
      case 4: rgba += [raw[index], raw[index], raw[index], raw[index + 1]]
      default: rgba += raw[index..<(index + 4)]
      }
    }
    return PixelImage(width: width, height: height, rgba: rgba)
  }

  public static func encode(_ image: PixelImage, to url: URL) throws {
    var scanlines = [UInt8]()
    scanlines.reserveCapacity((image.width * 4 + 1) * image.height)
    for y in 0..<image.height {
      scanlines.append(0)
      scanlines += image.rows(y..<(y + 1))
    }
    let bound = Int(compressBound(uLong(scanlines.count)))
    var compressed = [UInt8](repeating: 0, count: bound)
    var outputSize = uLongf(bound)
    let result = scanlines.withUnsafeBytes { source in
      compressed.withUnsafeMutableBytes { destination in
        compress2(
          destination.bindMemory(to: Bytef.self).baseAddress, &outputSize,
          source.bindMemory(to: Bytef.self).baseAddress, uLong(scanlines.count), Z_BEST_COMPRESSION)
      }
    }
    guard result == Z_OK else {
      throw ReconstructionFailure.outputWriteFailed(
        path: url.path, reason: "zlib compression failed")
    }
    compressed.removeSubrange(Int(outputSize)..<bound)
    var output = Data(signature)
    var header = [UInt8]()
    appendUInt32(UInt32(image.width), to: &header)
    appendUInt32(UInt32(image.height), to: &header)
    header += [8, 6, 0, 0, 0]
    appendChunk(type: "IHDR", payload: header, to: &output)
    appendChunk(type: "IDAT", payload: compressed, to: &output)
    appendChunk(type: "IEND", payload: [], to: &output)
    do { try output.write(to: url, options: .atomic) } catch {
      throw ReconstructionFailure.outputWriteFailed(
        path: url.path, reason: error.localizedDescription)
    }
  }

  private static func readUInt32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
    bytes[offset...offset + 3].reduce(0) { ($0 << 8) | UInt32($1) }
  }
  private static func appendUInt32(_ value: UInt32, to bytes: inout [UInt8]) {
    bytes += [
      UInt8(value >> 24), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255),
    ]
  }
  private static func appendChunk(type: String, payload: [UInt8], to data: inout Data) {
    var length = [UInt8]()
    appendUInt32(UInt32(payload.count), to: &length)
    data.append(contentsOf: length)
    let typeBytes = Array(type.utf8)
    data.append(contentsOf: typeBytes)
    data.append(contentsOf: payload)
    var crcInput = typeBytes + payload
    let crcCount = crcInput.count
    let checksum = crcInput.withUnsafeMutableBytes {
      crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(crcCount))
    }
    var crcBytes = [UInt8]()
    appendUInt32(UInt32(checksum), to: &crcBytes)
    data.append(contentsOf: crcBytes)
  }
  private static func paeth(_ a: UInt8, _ b: UInt8, _ c: UInt8) -> UInt8 {
    let p = Int(a) + Int(b) - Int(c)
    let pa = abs(p - Int(a))
    let pb = abs(p - Int(b))
    let pc = abs(p - Int(c))
    return pa <= pb && pa <= pc ? a : (pb <= pc ? b : c)
  }
}
