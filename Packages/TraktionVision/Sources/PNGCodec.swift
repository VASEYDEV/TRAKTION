/// Deterministic PNG encode/decode in pure Swift (no platform codec, no
/// external dependency). Identical input bytes produce identical output bytes
/// on every platform, which is required for golden-corpus comparisons
/// (docs/adr/ADR-002, ADR-005).
///
/// Decode supports the formats screenshots realistically use: 8-bit depth,
/// grayscale / truecolor / truecolor-alpha, non-interlaced. Everything else is
/// rejected with a typed error — never silently approximated.
/// Encode always writes 8-bit RGBA, filter 0, stored-block zlib.
public enum PNGError: Error, Equatable, Sendable {
    case notAPNG
    case truncated
    case invalidChunkLayout(details: String)
    case checksumMismatch(chunkType: String)
    case unsupportedFormat(details: String)
    case invalidPixelData(details: String)
    case compressionError(details: String)
}

public enum PNGCodec {
    static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

    // MARK: - Encode

    public static func encode(_ buffer: PixelBuffer) -> [UInt8] {
        var raw = [UInt8]()
        raw.reserveCapacity(buffer.height * (1 + buffer.width * 4))
        for y in 0..<buffer.height {
            raw.append(0) // filter type: None
            raw.append(contentsOf: buffer.row(y))
        }

        var ihdr = [UInt8]()
        appendBigEndian(UInt32(buffer.width), to: &ihdr)
        appendBigEndian(UInt32(buffer.height), to: &ihdr)
        ihdr.append(8)  // bit depth
        ihdr.append(6)  // color type: truecolor with alpha
        ihdr.append(0)  // compression
        ihdr.append(0)  // filter method
        ihdr.append(0)  // interlace: none

        var output = signature
        appendChunk(type: "IHDR", data: ihdr, to: &output)
        appendChunk(type: "IDAT", data: Zlib.compressStored(raw), to: &output)
        appendChunk(type: "IEND", data: [], to: &output)
        return output
    }

    // MARK: - Decode

    public static func decode(_ bytes: [UInt8]) throws -> PixelBuffer {
        guard bytes.count >= signature.count, Array(bytes[0..<8]) == signature else {
            throw PNGError.notAPNG
        }

        var offset = 8
        var header: (width: Int, height: Int, bitDepth: Int, colorType: Int)?
        var idat = [UInt8]()
        var sawEnd = false

        while offset < bytes.count {
            guard offset + 8 <= bytes.count else { throw PNGError.truncated }
            let length = Int(readBigEndian(bytes, at: offset))
            let typeBytes = bytes[offset + 4 ..< offset + 8]
            let type = String(decoding: typeBytes, as: UTF8.self)
            let dataStart = offset + 8
            guard dataStart + length + 4 <= bytes.count else { throw PNGError.truncated }
            let data = Array(bytes[dataStart ..< dataStart + length])
            let declaredCRC = readBigEndian(bytes, at: dataStart + length)
            guard Checksums.crc32(bytes[offset + 4 ..< dataStart + length]) == declaredCRC else {
                throw PNGError.checksumMismatch(chunkType: type)
            }
            offset = dataStart + length + 4

            switch type {
            case "IHDR":
                guard header == nil else {
                    throw PNGError.invalidChunkLayout(details: "duplicate IHDR")
                }
                guard data.count == 13 else {
                    throw PNGError.invalidChunkLayout(details: "IHDR length \(data.count)")
                }
                let width = Int(readBigEndian(data, at: 0))
                let height = Int(readBigEndian(data, at: 4))
                let bitDepth = Int(data[8])
                let colorType = Int(data[9])
                let interlace = Int(data[12])
                guard data[10] == 0, data[11] == 0 else {
                    throw PNGError.unsupportedFormat(details: "nonstandard compression/filter method")
                }
                guard interlace == 0 else {
                    throw PNGError.unsupportedFormat(details: "interlaced (Adam7) PNGs are not supported")
                }
                guard bitDepth == 8 else {
                    throw PNGError.unsupportedFormat(details: "bit depth \(bitDepth); only 8 is supported")
                }
                guard colorType == 0 || colorType == 2 || colorType == 6 else {
                    throw PNGError.unsupportedFormat(details: "color type \(colorType); supported: 0 (gray), 2 (RGB), 6 (RGBA)")
                }
                guard width > 0, height > 0 else {
                    throw PNGError.invalidChunkLayout(details: "empty image \(width)x\(height)")
                }
                header = (width, height, bitDepth, colorType)
            case "IDAT":
                guard header != nil else {
                    throw PNGError.invalidChunkLayout(details: "IDAT before IHDR")
                }
                idat.append(contentsOf: data)
            case "IEND":
                sawEnd = true
            default:
                continue // ancillary chunks (tEXt, pHYs, ...) are ignored
            }
            if sawEnd { break }
        }

        guard let header else { throw PNGError.invalidChunkLayout(details: "missing IHDR") }
        guard sawEnd else { throw PNGError.truncated }
        guard !idat.isEmpty else { throw PNGError.invalidChunkLayout(details: "missing IDAT") }

        let raw: [UInt8]
        do {
            raw = try Zlib.decompress(idat)
        } catch {
            throw PNGError.compressionError(details: String(describing: error))
        }

        let channels = header.colorType == 6 ? 4 : (header.colorType == 2 ? 3 : 1)
        let rowBytes = header.width * channels
        guard raw.count == header.height * (1 + rowBytes) else {
            throw PNGError.invalidPixelData(
                details: "expected \(header.height * (1 + rowBytes)) filtered bytes, found \(raw.count)"
            )
        }

        let unfiltered = try unfilter(raw, height: header.height, rowBytes: rowBytes, bytesPerPixel: channels)

        var pixels = [UInt8]()
        pixels.reserveCapacity(header.width * header.height * 4)
        switch channels {
        case 4:
            pixels = unfiltered
        case 3:
            var i = 0
            while i < unfiltered.count {
                pixels.append(unfiltered[i])
                pixels.append(unfiltered[i + 1])
                pixels.append(unfiltered[i + 2])
                pixels.append(255)
                i += 3
            }
        default:
            for value in unfiltered {
                pixels.append(value)
                pixels.append(value)
                pixels.append(value)
                pixels.append(255)
            }
        }
        return PixelBuffer(width: header.width, height: header.height, pixels: pixels)
    }

    // MARK: - Filters (RFC 2083 §6)

    private static func unfilter(
        _ raw: [UInt8], height: Int, rowBytes: Int, bytesPerPixel: Int
    ) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: height * rowBytes)
        for y in 0..<height {
            let filterType = raw[y * (1 + rowBytes)]
            let rowStart = y * (1 + rowBytes) + 1
            let outStart = y * rowBytes
            let prevStart = outStart - rowBytes
            for x in 0..<rowBytes {
                let value = raw[rowStart + x]
                let left = x >= bytesPerPixel ? output[outStart + x - bytesPerPixel] : 0
                let up = y > 0 ? output[prevStart + x] : 0
                let upLeft = (y > 0 && x >= bytesPerPixel) ? output[prevStart + x - bytesPerPixel] : 0
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
                    throw PNGError.invalidPixelData(details: "unknown filter type \(filterType) in row \(y)")
                }
                output[outStart + x] = reconstructed
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
