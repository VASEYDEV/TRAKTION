/// CRC-32 (ISO 3309, as used by PNG) and Adler-32 (RFC 1950).
enum Checksums {
    private static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for n in 0..<256 {
            var c = UInt32(n)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1
            }
            table[n] = c
        }
        return table
    }()

    static func crc32<S: Sequence>(_ bytes: S) -> UInt32 where S.Element == UInt8 {
        var c: UInt32 = 0xffffffff
        for byte in bytes {
            c = crcTable[Int((c ^ UInt32(byte)) & 0xff)] ^ (c >> 8)
        }
        return c ^ 0xffffffff
    }

    static func adler32<S: Sequence>(_ bytes: S) -> UInt32 where S.Element == UInt8 {
        let modulus: UInt32 = 65521
        var a: UInt32 = 1
        var b: UInt32 = 0
        for byte in bytes {
            a = (a &+ UInt32(byte)) % modulus
            b = (b &+ a) % modulus
        }
        return (b << 16) | a
    }
}
