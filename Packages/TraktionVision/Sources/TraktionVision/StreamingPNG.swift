import Foundation

public enum PNGStreamFailure: Error, Equatable, Sendable {
  case resourceLimit
  case malformedRow
  case nonOpaque
  case cancelled
}

/// Immutable checked sizes. Construction performs no reads, writes or allocations.
public struct PNGStreamAdmission: Sendable {
  public static let maximumPixels = 67_108_864
  public static let maximumRowBytes = 1_048_576
  public static let maximumEncodedBytes = 300 * 1_048_576
  public let width: Int
  public let height: Int
  public let rowBytes: Int
  public let filteredBytes: Int
  public let encodedBytes: Int
  public let workingBytes: Int

  public init(width: Int, height: Int, retainedBytes: Int = 0,
    maximumWorkingBytes: Int = 256 * 1_048_576) throws {
    func add(_ a: Int, _ b: Int) throws -> Int {
      let (n, overflow) = a.addingReportingOverflow(b)
      guard !overflow else { throw PNGStreamFailure.resourceLimit }; return n
    }
    func multiply(_ a: Int, _ b: Int) throws -> Int {
      let (n, overflow) = a.multipliedReportingOverflow(by: b)
      guard !overflow else { throw PNGStreamFailure.resourceLimit }; return n
    }
    guard width > 0, height > 0, width <= Int(UInt32.max), height <= Int(UInt32.max),
      retainedBytes >= 0, maximumWorkingBytes > 0,
      try multiply(width, height) <= Self.maximumPixels else { throw PNGStreamFailure.resourceLimit }
    let row = try multiply(width, 4)
    guard row <= Self.maximumRowBytes else { throw PNGStreamFailure.resourceLimit }
    let filtered = try multiply(add(row, 1), height)
    let blocks = try add(filtered, 65_534) / 65_535
    // One IDAT per stored block, plus zlib header/trailer IDATs; PNG signature/IHDR/IEND.
    let encoded = try add(add(filtered, multiply(blocks, 17)), 75)
    let working = try add(multiply(row, 3), 1_048_576)
    guard encoded <= Self.maximumEncodedBytes,
      try add(retainedBytes, working) <= maximumWorkingBytes else { throw PNGStreamFailure.resourceLimit }
    self.width = width; self.height = height; rowBytes = row
    filteredBytes = filtered; encodedBytes = encoded; workingBytes = working
  }
}

extension PNGCodec {
  /// The sink is synchronous and must consume each chunk without retaining it.
  /// Row providers must return exactly one opaque RGBA8 row. Errors propagate;
  /// callers must stage output privately and publish only after this returns.
  public static func streamOpaqueRGBA8(_ admission: PNGStreamAdmission,
    isCancelled: () -> Bool = { false },
    row: (Int) throws -> [UInt8], write: (Data) throws -> Void) throws {
    func check() throws { if isCancelled() { throw PNGStreamFailure.cancelled } }
    func be(_ value: UInt32) -> [UInt8] {
      [UInt8(truncatingIfNeeded: value >> 24), UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }
    func chunk(_ kind: String, _ payload: [UInt8]) throws {
      try check()
      var bytes = Array(kind.utf8)
      bytes.append(contentsOf: payload)
      let crc = Checksums.crc32(bytes[...])
      var framed = Data(be(UInt32(payload.count)))
      framed.append(contentsOf: bytes); framed.append(contentsOf: be(crc))
      try write(framed)
    }
    try check()
    try write(Data([137, 80, 78, 71, 13, 10, 26, 10]))
    try chunk("IHDR", be(UInt32(admission.width)) + be(UInt32(admission.height)) + [8, 6, 0, 0, 0])
    try chunk("IDAT", [0x78, 0x01])
    var block: [UInt8] = []
    block.reserveCapacity(65_535)
    var consumed = 0
    var a: UInt32 = 1, b: UInt32 = 0
    func append(_ bytes: ArraySlice<UInt8>) throws {
      var offset = bytes.startIndex
      while offset < bytes.endIndex {
        try check()
        let end = min(bytes.endIndex, offset + 65_535 - block.count)
        let part = bytes[offset..<end]
        for byte in part { a = (a + UInt32(byte)) % 65_521; b = (b + a) % 65_521 }
        block.append(contentsOf: part)
        consumed += part.count; offset = end
        if block.count == 65_535 || consumed == admission.filteredBytes {
          let length = UInt16(block.count), inverse = ~UInt16(block.count)
          let header: [UInt8] = [consumed == admission.filteredBytes ? 1 : 0,
            UInt8(truncatingIfNeeded: length), UInt8(truncatingIfNeeded: length >> 8),
            UInt8(truncatingIfNeeded: inverse), UInt8(truncatingIfNeeded: inverse >> 8)]
          try chunk("IDAT", header + block)
          block.removeAll(keepingCapacity: true)
        }
      }
    }
    for y in 0..<admission.height {
      try check()
      let pixels = try row(y)
      guard pixels.count == admission.rowBytes else { throw PNGStreamFailure.malformedRow }
      for alpha in stride(from: 3, to: pixels.count, by: 4) where pixels[alpha] != 255 {
        throw PNGStreamFailure.nonOpaque
      }
      try append([UInt8(0)][...])
      try append(pixels[...])
    }
    try chunk("IDAT", be((b << 16) | a))
    try chunk("IEND", [])
    try check()
  }
}
