import TraktionVision

/// Renders deterministic synthetic source canvases. The pattern is a pure
/// integer function of (x, y, seed), so identical parameters yield identical
/// pixels on every platform.
///
/// Every row is unique: a row-index marker strip and row-hash accents ensure
/// later overlap detection cannot be fooled by repeated rows, while wide color
/// bands keep the canvas screenshot-like rather than pure noise.
public enum CanvasRenderer {
    public static func render(width: Int, height: Int, seed: UInt64) -> PixelBuffer {
        precondition(width >= 8 && height >= 1, "canvas must be at least 8 pixels wide and 1 tall")
        var buffer = PixelBuffer(width: width, height: height)

        for y in 0..<height {
            let band = UInt64(y / 32)
            let bandHash = deterministicMix(seed, band)
            let bandColor = (
                r: UInt8(truncatingIfNeeded: bandHash >> 16),
                g: UInt8(truncatingIfNeeded: bandHash >> 24),
                b: UInt8(truncatingIfNeeded: bandHash >> 32)
            )
            let rowHash = deterministicMix(seed ^ 0xa5a5a5a5a5a5a5a5, UInt64(y))

            for x in 0..<width {
                var r = bandColor.r
                var g = bandColor.g
                var b = bandColor.b

                if x < 4 {
                    // Row-index marker strip: encodes y so every row differs.
                    let shift = UInt64(x * 8)
                    let value = UInt8(truncatingIfNeeded: UInt64(y) >> shift)
                    r = value
                    g = value ^ 0xff
                    b = UInt8(truncatingIfNeeded: rowHash)
                } else if (rowHash >> UInt64(8 + (x % 32))) & 1 == 1 && x % 7 == 0 {
                    // Sparse row-hash accents: text-like high-contrast marks.
                    r = r ^ 0x80
                    g = g ^ 0x80
                    b = b ^ 0x80
                }
                buffer.setPixel(x: x, y: y, r: r, g: g, b: b)
            }
        }
        return buffer
    }
}
