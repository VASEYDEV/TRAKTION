/// A working, in-memory RGBA8 raster. This is always a derived representation;
/// original capture files are never mutated (AGENTS.md source-integrity
/// invariant).
public struct PixelBuffer: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Row-major RGBA8; `count == width * height * 4`.
    public private(set) var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(width >= 0 && height >= 0, "dimensions must be non-negative")
        precondition(pixels.count == width * height * 4, "pixel count must be width*height*4")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public init(width: Int, height: Int, fill: (r: UInt8, g: UInt8, b: UInt8, a: UInt8) = (0, 0, 0, 255)) {
        precondition(width >= 0 && height >= 0, "dimensions must be non-negative")
        self.width = width
        self.height = height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        var i = 0
        while i < data.count {
            data[i] = fill.r
            data[i + 1] = fill.g
            data[i + 2] = fill.b
            data[i + 3] = fill.a
            i += 4
        }
        self.pixels = data
    }

    public func row(_ y: Int) -> ArraySlice<UInt8> {
        precondition(y >= 0 && y < height, "row out of bounds")
        let stride = width * 4
        return pixels[y * stride ..< (y + 1) * stride]
    }

    public mutating func setPixel(x: Int, y: Int, r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        precondition(x >= 0 && x < width && y >= 0 && y < height, "pixel out of bounds")
        let offset = (y * width + x) * 4
        pixels[offset] = r
        pixels[offset + 1] = g
        pixels[offset + 2] = b
        pixels[offset + 3] = a
    }

    public func pixel(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        precondition(x >= 0 && x < width && y >= 0 && y < height, "pixel out of bounds")
        let offset = (y * width + x) * 4
        return (pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3])
    }

    /// A new buffer containing rows `yOrigin ..< yOrigin + rowCount`.
    public func verticalSlice(yOrigin: Int, rowCount: Int) -> PixelBuffer {
        precondition(yOrigin >= 0 && rowCount >= 0 && yOrigin + rowCount <= height, "slice out of bounds")
        let stride = width * 4
        let slice = Array(pixels[yOrigin * stride ..< (yOrigin + rowCount) * stride])
        return PixelBuffer(width: width, height: rowCount, pixels: slice)
    }
}
