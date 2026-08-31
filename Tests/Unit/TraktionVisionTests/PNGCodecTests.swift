import Foundation
import Testing
@testable import TraktionVision

@Suite("PNG codec")
struct PNGCodecTests {
    /// 13x7 RGB interop image; pixel (x,y) = ((x*17+y*29)%256, (x*3)%256, (y*5)%256).
    /// Encoded by an independent implementation (CPython zlib) with an ancillary
    /// tEXt chunk; see docs/notes/2026-08-31-swift-bootstrap.md.
    private static let interopPNG =
        "iVBORw0KGgoAAAANSUhEUgAAAA0AAAAHCAIAAABcElBNAAAAD3RFWHRDb21tZW50AGludGVyb3DG6cWAAAABD0lEQVR42gXBMSj4QRQA4KfrLnedXq73q3tdXh1nMTAow9/AoAwMFjEwWMRgkRKDRUoWKSlZpKQkJSUlKSkpSUnJIiUli5Qshv/3AQDUK2g00G6hx8MgwniA2QqWI2wm2Bc4y3BbABpAtyrdZfSA1WNeT6NeDHq90rtRnyR9Lfop64+i4R+4PuVGjJuybsG7VXTbwR1V7jK6h+TexP1kZ4qDIcAJhXMGVyxueTxAPA94V+FLxK+ENYIhY1NBmAFaUrRhaM/SqacbpOdAnxX9RapLJEJtmboLwRrwjuJjw1eWHz2/I/8Grq2YI7ck7hTuzzxaGA5BLpTcG3m18u1FoVCQ5ko6ovQmGRaZzDJf5D+aRTjrjei+0QAAAABJRU5ErkJggg=="
    /// Same image, rows filtered with Sub/Up/Average/Paeth cycling per row.
    private static let filteredPNG =
        "iVBORw0KGgoAAAANSUhEUgAAAA0AAAAHCAIAAABcElBNAAAAOUlEQVR42mNkYGAQZCaMmGQZWIlBzDoMHOJMzAQRC1CtINBqvEiWgYGxhEGEqu5LYxBCc8p0bO4DAFNtCrMi1OQgAAAAAElFTkSuQmCC"

    private func interopExpected() -> PixelBuffer {
        var buffer = PixelBuffer(width: 13, height: 7)
        for y in 0..<7 {
            for x in 0..<13 {
                buffer.setPixel(
                    x: x, y: y,
                    r: UInt8((x * 17 + y * 29) % 256),
                    g: UInt8((x * 3) % 256),
                    b: UInt8((y * 5) % 256)
                )
            }
        }
        return buffer
    }

    private func bytes(fromBase64 string: String) -> [UInt8] {
        [UInt8](Data(base64Encoded: string)!)
    }

    @Test("Encode/decode round-trips RGBA pixels exactly")
    func roundTrip() throws {
        var buffer = PixelBuffer(width: 21, height: 13)
        for y in 0..<13 {
            for x in 0..<21 {
                buffer.setPixel(
                    x: x, y: y,
                    r: UInt8((x * 7 + y * 13) % 256),
                    g: UInt8((x * 29) % 256),
                    b: UInt8((y * 31) % 256),
                    a: UInt8((x + y * 3) % 256)
                )
            }
        }
        let decoded = try PNGCodec.decode(PNGCodec.encode(buffer))
        #expect(decoded == buffer)
    }

    @Test("Encoding is deterministic byte for byte")
    func deterministicEncoding() {
        let buffer = PixelBuffer(width: 33, height: 9, fill: (12, 200, 99, 255))
        #expect(PNGCodec.encode(buffer) == PNGCodec.encode(buffer))
    }

    @Test("Decodes an independently encoded RGB PNG, ignoring ancillary chunks")
    func interop() throws {
        let decoded = try PNGCodec.decode(bytes(fromBase64: Self.interopPNG))
        #expect(decoded == interopExpected())
    }

    @Test("Reconstructs Sub, Up, Average, and Paeth filtered rows")
    func filterReconstruction() throws {
        let decoded = try PNGCodec.decode(bytes(fromBase64: Self.filteredPNG))
        #expect(decoded == interopExpected())
    }

    @Test("Rejects non-PNG, truncated, and corrupted input with typed errors")
    func typedFailures() {
        #expect(throws: PNGError.notAPNG) { _ = try PNGCodec.decode([0, 1, 2, 3]) }

        let valid = bytes(fromBase64: Self.interopPNG)
        #expect(throws: PNGError.truncated) { _ = try PNGCodec.decode(Array(valid.dropLast(5))) }

        var corrupted = valid
        corrupted[corrupted.count - 1] ^= 0xff // IEND CRC
        #expect(throws: PNGError.checksumMismatch(chunkType: "IEND")) { _ = try PNGCodec.decode(corrupted) }
    }

    @Test("Rejects unsupported formats instead of approximating them")
    func unsupportedFormats() {
        // Rebuild the interop image header with bit depth 16 and a fixed-up CRC.
        var png = bytes(fromBase64: Self.interopPNG)
        png[24] = 16 // IHDR bit-depth byte
        let typeAndData = png[12..<29]
        let crc = Checksums.crc32(typeAndData)
        png[29] = UInt8(truncatingIfNeeded: crc >> 24)
        png[30] = UInt8(truncatingIfNeeded: crc >> 16)
        png[31] = UInt8(truncatingIfNeeded: crc >> 8)
        png[32] = UInt8(truncatingIfNeeded: crc)
        #expect(throws: PNGError.unsupportedFormat(details: "bit depth 16; only 8 is supported")) {
            _ = try PNGCodec.decode(png)
        }
    }
}
