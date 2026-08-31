/// DEFLATE (RFC 1951) decompression and zlib (RFC 1950) framing, implemented
/// in pure Swift so decoding is deterministic and dependency-free on every
/// platform. Correctness outranks throughput at this stage; the decoder is
/// exercised against real zlib output in the test suite.
public enum InflateError: Error, Equatable, Sendable {
    case truncated
    case invalidBlockType
    case invalidStoredBlockLength
    case invalidHuffmanTable
    case invalidSymbol
    case invalidDistance
    case invalidZlibHeader
    case checksumMismatch(expected: UInt32, found: UInt32)
}

struct BitReader {
    private let bytes: [UInt8]
    private(set) var bytePosition: Int
    private var bitPosition: Int

    init(_ bytes: [UInt8], startingAt offset: Int = 0) {
        self.bytes = bytes
        self.bytePosition = offset
        self.bitPosition = 0
    }

    mutating func bit() throws -> Int {
        guard bytePosition < bytes.count else { throw InflateError.truncated }
        let value = (Int(bytes[bytePosition]) >> bitPosition) & 1
        bitPosition += 1
        if bitPosition == 8 {
            bitPosition = 0
            bytePosition += 1
        }
        return value
    }

    /// Reads `count` bits, LSB first (RFC 1951 §3.1.1).
    mutating func bits(_ count: Int) throws -> Int {
        var value = 0
        for i in 0..<count {
            value |= try bit() << i
        }
        return value
    }

    mutating func alignToByte() {
        if bitPosition != 0 {
            bitPosition = 0
            bytePosition += 1
        }
    }

    mutating func byte() throws -> UInt8 {
        precondition(bitPosition == 0, "byte reads require byte alignment")
        guard bytePosition < bytes.count else { throw InflateError.truncated }
        defer { bytePosition += 1 }
        return bytes[bytePosition]
    }
}

/// Canonical Huffman decoding table built from code lengths (RFC 1951 §3.2.2).
struct HuffmanTable {
    private let counts: [Int]        // number of codes per bit length (index 0 unused)
    private let symbols: [Int]       // symbols sorted by (length, symbol value)

    init(lengths: [Int]) throws {
        var counts = [Int](repeating: 0, count: 16)
        for length in lengths {
            guard length >= 0 && length <= 15 else { throw InflateError.invalidHuffmanTable }
            counts[length] += 1
        }
        counts[0] = 0

        // Reject over-subscribed tables; incomplete tables are tolerated
        // (they occur legitimately, e.g. a single-distance-code stream).
        var left = 1
        for length in 1...15 {
            left <<= 1
            left -= counts[length]
            guard left >= 0 else { throw InflateError.invalidHuffmanTable }
        }

        var offsets = [Int](repeating: 0, count: 16)
        for length in 1..<15 {
            offsets[length + 1] = offsets[length] + counts[length]
        }
        var symbols = [Int](repeating: 0, count: lengths.count)
        for (symbol, length) in lengths.enumerated() where length != 0 {
            symbols[offsets[length]] = symbol
            offsets[length] += 1
        }

        self.counts = counts
        self.symbols = symbols
    }

    func decode(_ reader: inout BitReader) throws -> Int {
        var code = 0
        var first = 0
        var index = 0
        for length in 1...15 {
            code |= try reader.bit()
            let count = counts[length]
            if code - first < count {
                return symbols[index + (code - first)]
            }
            index += count
            first = (first + count) << 1
            code <<= 1
        }
        throw InflateError.invalidSymbol
    }
}

enum Inflate {
    private static let lengthBases = [
        3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
        35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
    ]
    private static let lengthExtraBits = [
        0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
        3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
    ]
    private static let distanceBases = [
        1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
        257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
    ]
    private static let distanceExtraBits = [
        0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
        7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
    ]
    private static let codeLengthOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    /// Raw DEFLATE stream (no zlib framing).
    static func decompress(_ input: [UInt8], startingAt offset: Int = 0) throws -> (output: [UInt8], bytesRead: Int) {
        var reader = BitReader(input, startingAt: offset)
        var output = [UInt8]()

        while true {
            let isFinal = try reader.bit() == 1
            let blockType = try reader.bits(2)

            switch blockType {
            case 0:
                reader.alignToByte()
                let low = Int(try reader.byte())
                let high = Int(try reader.byte())
                let nLow = Int(try reader.byte())
                let nHigh = Int(try reader.byte())
                let length = low | (high << 8)
                let complement = nLow | (nHigh << 8)
                guard length ^ 0xffff == complement else { throw InflateError.invalidStoredBlockLength }
                for _ in 0..<length {
                    output.append(try reader.byte())
                }
            case 1:
                var literalLengths = [Int](repeating: 8, count: 288)
                for i in 144...255 { literalLengths[i] = 9 }
                for i in 256...279 { literalLengths[i] = 7 }
                let literalTable = try HuffmanTable(lengths: literalLengths)
                let distanceTable = try HuffmanTable(lengths: [Int](repeating: 5, count: 30))
                try decodeCompressedBlock(&reader, literalTable, distanceTable, into: &output)
            case 2:
                let literalCount = try reader.bits(5) + 257
                let distanceCount = try reader.bits(5) + 1
                let codeLengthCount = try reader.bits(4) + 4
                guard literalCount <= 286, distanceCount <= 30 else { throw InflateError.invalidHuffmanTable }

                var codeLengthLengths = [Int](repeating: 0, count: 19)
                for i in 0..<codeLengthCount {
                    codeLengthLengths[codeLengthOrder[i]] = try reader.bits(3)
                }
                let codeLengthTable = try HuffmanTable(lengths: codeLengthLengths)

                var lengths = [Int]()
                lengths.reserveCapacity(literalCount + distanceCount)
                while lengths.count < literalCount + distanceCount {
                    let symbol = try codeLengthTable.decode(&reader)
                    switch symbol {
                    case 0...15:
                        lengths.append(symbol)
                    case 16:
                        guard let previous = lengths.last else { throw InflateError.invalidHuffmanTable }
                        let repeatCount = try reader.bits(2) + 3
                        lengths.append(contentsOf: [Int](repeating: previous, count: repeatCount))
                    case 17:
                        let repeatCount = try reader.bits(3) + 3
                        lengths.append(contentsOf: [Int](repeating: 0, count: repeatCount))
                    case 18:
                        let repeatCount = try reader.bits(7) + 11
                        lengths.append(contentsOf: [Int](repeating: 0, count: repeatCount))
                    default:
                        throw InflateError.invalidSymbol
                    }
                }
                guard lengths.count == literalCount + distanceCount else { throw InflateError.invalidHuffmanTable }

                let literalTable = try HuffmanTable(lengths: Array(lengths[0..<literalCount]))
                let distanceTable = try HuffmanTable(lengths: Array(lengths[literalCount...]))
                try decodeCompressedBlock(&reader, literalTable, distanceTable, into: &output)
            default:
                throw InflateError.invalidBlockType
            }

            if isFinal { break }
        }

        reader.alignToByte()
        return (output, reader.bytePosition - offset)
    }

    private static func decodeCompressedBlock(
        _ reader: inout BitReader,
        _ literalTable: HuffmanTable,
        _ distanceTable: HuffmanTable,
        into output: inout [UInt8]
    ) throws {
        while true {
            let symbol = try literalTable.decode(&reader)
            if symbol < 256 {
                output.append(UInt8(symbol))
            } else if symbol == 256 {
                return
            } else {
                guard symbol <= 285 else { throw InflateError.invalidSymbol }
                let lengthIndex = symbol - 257
                let length = lengthBases[lengthIndex] + (try reader.bits(lengthExtraBits[lengthIndex]))

                let distanceSymbol = try distanceTable.decode(&reader)
                guard distanceSymbol < 30 else { throw InflateError.invalidDistance }
                let distance = distanceBases[distanceSymbol] + (try reader.bits(distanceExtraBits[distanceSymbol]))
                guard distance <= output.count else { throw InflateError.invalidDistance }

                let start = output.count - distance
                for i in 0..<length {
                    output.append(output[start + i])
                }
            }
        }
    }
}

enum Zlib {
    /// Decompresses a zlib stream (RFC 1950) and verifies its Adler-32 trailer.
    static func decompress(_ input: [UInt8]) throws -> [UInt8] {
        guard input.count >= 6 else { throw InflateError.truncated }
        let cmf = input[0]
        let flg = input[1]
        guard cmf & 0x0f == 8 else { throw InflateError.invalidZlibHeader }
        guard (UInt16(cmf) << 8 | UInt16(flg)) % 31 == 0 else { throw InflateError.invalidZlibHeader }
        guard flg & 0x20 == 0 else { throw InflateError.invalidZlibHeader } // preset dictionaries unsupported

        let (output, bytesRead) = try Inflate.decompress(input, startingAt: 2)
        let trailerStart = 2 + bytesRead
        guard trailerStart + 4 <= input.count else { throw InflateError.truncated }
        let expected = UInt32(input[trailerStart]) << 24
            | UInt32(input[trailerStart + 1]) << 16
            | UInt32(input[trailerStart + 2]) << 8
            | UInt32(input[trailerStart + 3])
        let found = Checksums.adler32(output)
        guard expected == found else {
            throw InflateError.checksumMismatch(expected: expected, found: found)
        }
        return output
    }

    /// Compresses with stored (uncompressed) DEFLATE blocks inside zlib
    /// framing. Deterministic and codec-independent; output size ≈ input + 11
    /// bytes + 5 per 64 KiB block. Real entropy coding can come later without
    /// changing any caller.
    static func compressStored(_ input: [UInt8]) -> [UInt8] {
        var output: [UInt8] = [0x78, 0x01] // CMF/FLG: deflate, 32K window, fastest
        var offset = 0
        repeat {
            let blockLength = min(65535, input.count - offset)
            let isFinal = offset + blockLength == input.count
            output.append(isFinal ? 1 : 0)
            output.append(UInt8(blockLength & 0xff))
            output.append(UInt8(blockLength >> 8))
            output.append(UInt8(~blockLength & 0xff))
            output.append(UInt8((~blockLength >> 8) & 0xff))
            output.append(contentsOf: input[offset ..< offset + blockLength])
            offset += blockLength
        } while offset < input.count

        let adler = Checksums.adler32(input)
        output.append(UInt8(truncatingIfNeeded: adler >> 24))
        output.append(UInt8(truncatingIfNeeded: adler >> 16))
        output.append(UInt8(truncatingIfNeeded: adler >> 8))
        output.append(UInt8(truncatingIfNeeded: adler))
        return output
    }
}
