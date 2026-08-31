import Foundation
import Testing
@testable import TraktionVision

@Suite("Checksums")
struct ChecksumTests {
    @Test("CRC-32 and Adler-32 match published reference vectors")
    func referenceVectors() {
        #expect(Checksums.crc32(Array("123456789".utf8)) == 0xcbf43926)
        #expect(Checksums.crc32([]) == 0)
        #expect(Checksums.adler32(Array("Wikipedia".utf8)) == 0x11e60398)
        #expect(Checksums.adler32([]) == 1)
    }
}

@Suite("Inflate / zlib")
struct InflateTests {
    // Vectors produced by CPython's zlib (see docs/notes/2026-08-31-swift-bootstrap.md).
    private static let repetitiveTextZlib =
        "eNoLCXL0DvH091MoSk3OzysuKSpNLilWKC4tKMjJTE1RKMssLk3MUUgty0xJzUtO1VMIGVU/qn5U/aj6UfWj6kfVU6weAM3Awg8="
    private static let patternBytesZlib =
        "eJxj5hZV1LcPTK2evPbkcx69oIoFp75pRnbv/2qUs+KZdu7G7y59t3Rrz2vUXTOd+D5km3zr25gT1quVpgl2crSwt/NNkl1qciD4cZXwSrcHjSpHskV2pYsdKtW6MzWA93iHt8Cl2WnGTOcWlvmqMd7cMbMm0cNQhvPzk+tnDu/ZvmXzlu17Dp+5/uQzp4yhR2LNzB03GdV8yxaeYzJOm31JwLvjOG/A1DtapYfE0neJZB9RaXzgtlK46nHwAZOlspP42tlbODoFpymttj4R87ZVflvI+4mm1+o0ztfq3upz+b4xV/vZihyjr/u7IzW/nVpQEaTH8/zk2snVqYH2+oqi3Mw/vnz69OUH86jXR70+6vVRr496fdTro14f9fqo10e9Pur1Ua+Pen3U6yPF6wDLoa6V"
    private static let tinyZlib = "eNpLTEoGAAJNASc="

    private func bytes(fromBase64 string: String) -> [UInt8] {
        [UInt8](Data(base64Encoded: string)!)
    }

    @Test("Decompresses real zlib output (dynamic and fixed Huffman)")
    func realZlibStreams() throws {
        let text = Array(String(repeating: "TRAKTION reconstructs supplied visual evidence. ", count: 40).utf8)
        #expect(try Zlib.decompress(bytes(fromBase64: Self.repetitiveTextZlib)) == text)

        let pattern: [UInt8] = (0..<4096).map { (i: Int) -> UInt8 in
            let value = (i * i + 7 * i + 3) % 251
            return UInt8(value)
        }
        #expect(try Zlib.decompress(bytes(fromBase64: Self.patternBytesZlib)) == pattern)

        #expect(try Zlib.decompress(bytes(fromBase64: Self.tinyZlib)) == Array("abc".utf8))
    }

    @Test("Stored-block compression round-trips, including multi-block payloads")
    func storedRoundTrip() throws {
        let payloads: [[UInt8]] = [
            [],
            [42],
            Array("short payload".utf8),
            (0..<70_000).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }, // > one 64 KiB block
        ]
        for payload in payloads {
            #expect(try Zlib.decompress(Zlib.compressStored(payload)) == payload)
        }
    }

    @Test("Corrupted streams fail with typed errors, never partial output")
    func typedFailures() {
        var corrupted = bytes(fromBase64: Self.tinyZlib)
        corrupted[corrupted.count - 1] ^= 0xff
        #expect(throws: InflateError.self) { try Zlib.decompress(corrupted) }

        #expect(throws: InflateError.invalidZlibHeader) { try Zlib.decompress([0x00, 0x00, 0, 0, 0, 0]) }
        #expect(throws: InflateError.truncated) { try Zlib.decompress([0x78]) }
    }
}
