import TraktionDomain

// The prompt-02 control set (docs/tasks/0003): deterministic generation of the
// adversarial and positive-control fixture families, each carrying ground
// truth that records both the semantic condition and the exact behavior
// today's engine must exhibit. Same configuration, same bytes — always.

public enum FixtureVariant: Equatable, Sendable {
  case baseline
  /// A byte-identical copy of the first capture appended at the end
  /// (nonadjacent, exercising global duplicate detection).
  case duplicateCapture
  case reversedOrder
  /// The middle capture is dropped, leaving a coverage gap.
  case missingMiddle
  /// The top `rows` of every capture carry an identical fixed header.
  case stickyHeader(rows: Int)
  /// The bottom `rows` of every capture carry an identical fixed footer.
  case stickyFooter(rows: Int)
  /// A fixed-position control occludes content near the bottom-right of
  /// every capture.
  case floatingControl(width: Int, height: Int)
  /// A right-edge scrollbar whose thumb position tracks each capture's origin.
  case scrollbar(width: Int)
  /// Capture origins jittered by one pixel from the uniform stride.
  case onePixelOffset
  /// Per-capture deterministic noise of at most `maxChannelDelta` per channel,
  /// simulating a lossy capture pipeline (overlaps become near-exact).
  case degraded(maxChannelDelta: Int)

  public var name: String {
    switch self {
    case .baseline: return "baseline"
    case .duplicateCapture: return "duplicate-capture"
    case .reversedOrder: return "reversed-order"
    case .missingMiddle: return "missing-middle"
    case .stickyHeader: return "sticky-header"
    case .stickyFooter: return "sticky-footer"
    case .floatingControl: return "floating-control"
    case .scrollbar: return "scrollbar"
    case .onePixelOffset: return "one-pixel-offset"
    case .degraded: return "degraded"
    }
  }

  /// CLI entry point: variant by name with documented default parameters.
  public static func named(_ name: String) -> FixtureVariant? {
    switch name {
    case "baseline": return .baseline
    case "duplicate-capture": return .duplicateCapture
    case "reversed-order": return .reversedOrder
    case "missing-middle": return .missingMiddle
    case "sticky-header": return .stickyHeader(rows: 12)
    case "sticky-footer": return .stickyFooter(rows: 12)
    case "floating-control": return .floatingControl(width: 14, height: 14)
    case "scrollbar": return .scrollbar(width: 4)
    case "one-pixel-offset": return .onePixelOffset
    case "degraded": return .degraded(maxChannelDelta: 2)
    default: return nil
    }
  }

  public static let allNames = [
    "baseline", "duplicate-capture", "reversed-order", "missing-middle",
    "sticky-header", "sticky-footer", "floating-control", "scrollbar",
    "one-pixel-offset", "degraded",
  ]
}

public struct FixtureControlConfiguration: Equatable, Sendable {
  public var sourceID: String
  public var axis: ReconstructionAxis
  /// Size across the reconstruction axis (width for vertical fixtures).
  public var crossAxisSize: Int
  /// Capture extent along the reconstruction axis.
  public var viewportLength: Int
  public var captureCount: Int
  public var overlapLength: Int
  public var seed: UInt64
  public var variant: FixtureVariant

  public init(
    sourceID: String = "control",
    axis: ReconstructionAxis = .vertical,
    crossAxisSize: Int = 64,
    viewportLength: Int = 96,
    captureCount: Int = 3,
    overlapLength: Int = 24,
    seed: UInt64 = 0x5452_414B,
    variant: FixtureVariant = .baseline
  ) {
    self.sourceID = sourceID
    self.axis = axis
    self.crossAxisSize = crossAxisSize
    self.viewportLength = viewportLength
    self.captureCount = captureCount
    self.overlapLength = overlapLength
    self.seed = seed
    self.variant = variant
  }

  public var sourceLength: Int {
    captureCount * viewportLength - (captureCount - 1) * overlapLength
  }
}

/// Ground truth written as `fixture.json` next to generated captures.
/// `expectedStatus` names the semantic condition; `expectedFailureCode` pins
/// what the current engine must return (nil = must reconstruct). When later
/// milestones change engine capability, expected codes change here — the
/// semantic status does not.
public struct FixtureGroundTruth: Codable, Equatable, Sendable {
  public struct Capture: Codable, Equatable, Sendable {
    public let id: String
    public let fileName: String
    /// Origin along the reconstruction axis inside the source canvas.
    public let sourceOrigin: Int
    public let width: Int
    public let height: Int

    public init(id: String, fileName: String, sourceOrigin: Int, width: Int, height: Int) {
      self.id = id
      self.fileName = fileName
      self.sourceOrigin = sourceOrigin
      self.width = width
      self.height = height
    }
  }

  public let schemaVersion: Int
  public let fixtureName: String
  public let sourceID: String
  public let axis: String
  public let seed: UInt64
  public let sourceWidth: Int
  public let sourceHeight: Int
  public let sourceFileName: String
  /// FNV-1a 64 fingerprint of the source dimensions and raw RGBA pixels —
  /// platform-independent, unlike encoded PNG bytes.
  public let sourcePixelFingerprint: String
  /// Captures in supplied order (the order handed to the engine).
  public let captures: [Capture]
  /// Capture IDs in true document order.
  public let expectedOrder: [String]
  /// Overlaps between supplied-order neighbors; empty when the variant makes
  /// supplied adjacency meaningless (reversed, missing coverage, duplicates).
  public let expectedOverlaps: [Int]
  public let expectedStatus: String
  public let expectedFailureCode: String?

  public init(
    schemaVersion: Int = 1,
    fixtureName: String,
    sourceID: String,
    axis: String,
    seed: UInt64,
    sourceWidth: Int,
    sourceHeight: Int,
    sourceFileName: String,
    sourcePixelFingerprint: String,
    captures: [Capture],
    expectedOrder: [String],
    expectedOverlaps: [Int],
    expectedStatus: String,
    expectedFailureCode: String?
  ) {
    self.schemaVersion = schemaVersion
    self.fixtureName = fixtureName
    self.sourceID = sourceID
    self.axis = axis
    self.seed = seed
    self.sourceWidth = sourceWidth
    self.sourceHeight = sourceHeight
    self.sourceFileName = sourceFileName
    self.sourcePixelFingerprint = sourcePixelFingerprint
    self.captures = captures
    self.expectedOrder = expectedOrder
    self.expectedOverlaps = expectedOverlaps
    self.expectedStatus = expectedStatus
    self.expectedFailureCode = expectedFailureCode
  }
}

public struct FixtureControlBundle: Sendable {
  public let configuration: FixtureControlConfiguration
  /// The documentary source canvas (already transposed for horizontal fixtures).
  public let source: RasterImage
  /// Final captures in supplied order, after variant mutation.
  public let captures: [CaptureAsset]
  public let groundTruth: FixtureGroundTruth
}

public enum FixtureControlGeneratorError: Error, Equatable, Sendable {
  case invalidConfiguration(String)
}

public enum FixtureControlGenerator {
  public static func generate(
    _ configuration: FixtureControlConfiguration
  ) throws -> FixtureControlBundle {
    try validate(configuration)

    let config = configuration
    let source = try SyntheticFixtureFactory.document(
      width: config.crossAxisSize,
      height: config.sourceLength,
      seed: config.seed
    )

    // Everything is generated in vertical orientation; horizontal fixtures
    // are transposed at the end.
    var origins = baseOrigins(config)
    if case .onePixelOffset = config.variant {
      origins = jitterByOnePixel(origins, config)
    }

    var slices = try origins.map { origin in
      try crop(source, startRow: origin, rowCount: config.viewportLength)
    }
    slices = try applyOverlay(config, to: slices, origins: origins)

    var finalImages = slices
    var finalOrigins = origins
    switch config.variant {
    case .duplicateCapture:
      finalImages.append(slices[0])
      finalOrigins.append(origins[0])
    case .reversedOrder:
      finalImages.reverse()
      finalOrigins.reverse()
    case .missingMiddle:
      let middle = config.captureCount / 2
      finalImages.remove(at: middle)
      finalOrigins.remove(at: middle)
    default:
      break
    }

    var finalSource = source
    if config.axis == .horizontal {
      finalSource = try transpose(source)
      finalImages = try finalImages.map(transpose)
    }

    let captures = finalImages.enumerated().map { index, image in
      CaptureAsset(
        id: CaptureID(fileID(index)),
        sourceName: "\(fileID(index)).png",
        image: image
      )
    }

    let truthCaptures = captures.enumerated().map { index, capture in
      FixtureGroundTruth.Capture(
        id: capture.id.rawValue,
        fileName: capture.sourceName,
        sourceOrigin: finalOrigins[index],
        width: capture.image.width,
        height: capture.image.height
      )
    }
    let expectedOrder = truthCaptures
      .enumerated()
      .sorted { lhs, rhs in
        lhs.element.sourceOrigin != rhs.element.sourceOrigin
          ? lhs.element.sourceOrigin < rhs.element.sourceOrigin
          : lhs.offset < rhs.offset
      }
      .map(\.element.id)
    let expectation = expectation(for: config)
    let overlaps: [Int]
    if expectation.failureCode == nil {
      overlaps = (1..<finalOrigins.count).map { index in
        finalOrigins[index - 1] + config.viewportLength - finalOrigins[index]
      }
    } else {
      overlaps = []
    }

    let groundTruth = FixtureGroundTruth(
      fixtureName: "\(config.variant.name)-\(config.axis.rawValue)",
      sourceID: config.sourceID,
      axis: config.axis.rawValue,
      seed: config.seed,
      sourceWidth: finalSource.width,
      sourceHeight: finalSource.height,
      sourceFileName: "source.png",
      sourcePixelFingerprint: fingerprint(finalSource),
      captures: truthCaptures,
      expectedOrder: expectedOrder,
      expectedOverlaps: overlaps,
      expectedStatus: expectation.status,
      expectedFailureCode: expectation.failureCode
    )

    return FixtureControlBundle(
      configuration: config,
      source: finalSource,
      captures: captures,
      groundTruth: groundTruth
    )
  }

  // MARK: - Expectations

  /// The behavior the current engine must exhibit per variant, pinned by the
  /// golden tests in `Tests/Golden/FixtureControlSetTests.swift`. Every
  /// adversarial case must end in a typed failure — a silently wrong
  /// composite is a defect, never an expectation.
  private static func expectation(
    for config: FixtureControlConfiguration
  ) -> (status: String, failureCode: String?) {
    if config.axis == .horizontal {
      return ("unsupported-axis", "unsupportedAxis")
    }
    switch config.variant {
    case .baseline:
      return ("reconstructable", nil)
    case .onePixelOffset:
      return ("reconstructable", nil)
    case .degraded:
      return ("reconstructable-near-exact", nil)
    case .duplicateCapture:
      return ("duplicate-capture", "duplicateCapture")
    case .reversedOrder:
      return ("reversed-order", "insufficientOverlap")
    case .missingMiddle:
      return ("missing-coverage", "insufficientOverlap")
    case .stickyHeader:
      return ("sticky-header-occlusion", "insufficientOverlap")
    case .stickyFooter:
      return ("sticky-footer-occlusion", "insufficientOverlap")
    case .floatingControl:
      return ("floating-control-occlusion", "insufficientOverlap")
    case .scrollbar:
      // Empirically pinned: the thumb's differences stay outside or below the
      // acceptance thresholds, the unique true overlap wins, and the composite
      // faithfully carries the scrollbar pixels of whichever capture owns each
      // span. That is honest stitching of what the captures contain — not
      // corruption. Milestone 4 owns scrollbar detection and cosmetics.
      return ("reconstructable-with-scrollbar-artifacts", nil)
    }
  }

  // MARK: - Geometry

  private static func baseOrigins(_ config: FixtureControlConfiguration) -> [Int] {
    let stride = config.viewportLength - config.overlapLength
    return (0..<config.captureCount).map { $0 * stride }
  }

  /// Jitters interior origins only: the first and last captures keep their
  /// base origins so the sequence still covers the full source canvas.
  private static func jitterByOnePixel(
    _ origins: [Int],
    _ config: FixtureControlConfiguration
  ) -> [Int] {
    origins.enumerated().map { index, origin in
      if index == 0 || index == origins.count - 1 { return origin }
      return origin + (index % 2 == 1 ? 1 : -1)
    }
  }

  // MARK: - Overlays

  private static func applyOverlay(
    _ config: FixtureControlConfiguration,
    to slices: [RasterImage],
    origins: [Int]
  ) throws -> [RasterImage] {
    switch config.variant {
    case .stickyHeader(let rows):
      return try slices.map { try paintFixedBand($0, rowRange: 0..<rows, seed: config.seed) }
    case .stickyFooter(let rows):
      return try slices.map {
        try paintFixedBand($0, rowRange: ($0.height - rows)..<$0.height, seed: config.seed)
      }
    case .floatingControl(let width, let height):
      return try slices.map { slice in
        try paintBlock(
          slice,
          x: slice.width - width - 6,
          y: slice.height - height - 6,
          width: width,
          height: height,
          color: (36, 99, 235)
        )
      }
    case .scrollbar(let width):
      let travel = config.sourceLength - config.viewportLength
      return try slices.enumerated().map { index, slice in
        try paintScrollbar(
          slice,
          barWidth: width,
          origin: origins[index],
          travel: travel
        )
      }
    case .degraded(let maxDelta):
      return try slices.enumerated().map { index, slice in
        try degrade(slice, captureIndex: index, maxDelta: maxDelta, seed: config.seed)
      }
    default:
      return slices
    }
  }

  /// A fixed chrome band identical across captures; rows differ from each
  /// other so the band itself never creates repeated rows within one capture.
  private static func paintFixedBand(
    _ image: RasterImage,
    rowRange: Range<Int>,
    seed: UInt64
  ) throws -> RasterImage {
    var pixels = image.pixels
    for (bandRow, row) in rowRange.enumerated() {
      for x in 0..<image.width {
        let offset = image.byteOffset(x: x, y: row)
        let accent = mix(seed &+ 0xC0FFEE, UInt64(bandRow &* 131 &+ x))
        pixels[offset] = 28 &+ UInt8(truncatingIfNeeded: accent % 5)
        pixels[offset + 1] = 34 &+ UInt8(truncatingIfNeeded: (accent >> 8) % 5)
        pixels[offset + 2] = 46 &+ UInt8(truncatingIfNeeded: (accent >> 16) % 5)
        pixels[offset + 3] = 255
      }
    }
    return try RasterImage(width: image.width, height: image.height, pixels: pixels)
  }

  private static func paintBlock(
    _ image: RasterImage,
    x: Int,
    y: Int,
    width: Int,
    height: Int,
    color: (UInt8, UInt8, UInt8)
  ) throws -> RasterImage {
    var pixels = image.pixels
    for row in y..<(y + height) {
      for column in x..<(x + width) {
        let offset = image.byteOffset(x: column, y: row)
        pixels[offset] = color.0
        pixels[offset + 1] = color.1
        pixels[offset + 2] = color.2
        pixels[offset + 3] = 255
      }
    }
    return try RasterImage(width: image.width, height: image.height, pixels: pixels)
  }

  private static func paintScrollbar(
    _ image: RasterImage,
    barWidth: Int,
    origin: Int,
    travel: Int
  ) throws -> RasterImage {
    var pixels = image.pixels
    let thumbLength = max(8, image.height * image.height / (travel + image.height))
    let thumbStart = travel == 0
      ? 0
      : origin * (image.height - thumbLength) / travel
    for row in 0..<image.height {
      let inThumb = row >= thumbStart && row < thumbStart + thumbLength
      for column in (image.width - barWidth)..<image.width {
        let offset = image.byteOffset(x: column, y: row)
        let value: UInt8 = inThumb ? 96 : 236
        pixels[offset] = value
        pixels[offset + 1] = value
        pixels[offset + 2] = value
        pixels[offset + 3] = 255
      }
    }
    return try RasterImage(width: image.width, height: image.height, pixels: pixels)
  }

  private static func degrade(
    _ image: RasterImage,
    captureIndex: Int,
    maxDelta: Int,
    seed: UInt64
  ) throws -> RasterImage {
    var pixels = image.pixels
    let span = UInt64(2 * maxDelta + 1)
    for y in 0..<image.height {
      for x in 0..<image.width {
        let offset = image.byteOffset(x: x, y: y)
        for channel in 0..<3 {
          let noise = mix(
            seed &+ UInt64(captureIndex) &* 0x9E37_79B9,
            UInt64(y) &* 8191 &+ UInt64(x) &* 31 &+ UInt64(channel)
          )
          let delta = Int(noise % span) - maxDelta
          let value = Int(pixels[offset + channel]) + delta
          pixels[offset + channel] = UInt8(min(255, max(0, value)))
        }
      }
    }
    return try RasterImage(width: image.width, height: image.height, pixels: pixels)
  }

  // MARK: - Utilities

  private static func validate(_ config: FixtureControlConfiguration) throws {
    func reject(_ reason: String) throws -> Never {
      throw FixtureControlGeneratorError.invalidConfiguration(reason)
    }
    if config.crossAxisSize < 16 { try reject("crossAxisSize must be at least 16") }
    if config.viewportLength < 16 { try reject("viewportLength must be at least 16") }
    if !(2...10).contains(config.captureCount) { try reject("captureCount must be 2-10") }
    if config.overlapLength < 1 || config.overlapLength >= config.viewportLength {
      try reject("overlapLength must be in 1..<viewportLength")
    }
    switch config.variant {
    case .duplicateCapture where config.captureCount >= 10:
      try reject("duplicate-capture needs captureCount <= 9 (the duplicate adds one)")
    case .missingMiddle where config.captureCount < 3:
      try reject("missing-middle needs at least 3 captures")
    case .onePixelOffset where config.overlapLength < 10:
      try reject("one-pixel-offset needs overlapLength >= 10 to stay above the engine minimum")
    case .onePixelOffset where config.captureCount < 3:
      try reject("one-pixel-offset needs at least 3 captures (only interior origins jitter)")
    case .stickyHeader(let rows), .stickyFooter(let rows):
      if rows < 2 || rows >= config.viewportLength / 3 {
        try reject("sticky band rows must be in 2..<viewportLength/3")
      }
    case .floatingControl(let width, let height):
      if width < 4 || height < 4 || width + 12 > config.crossAxisSize
        || height + 12 > config.viewportLength
      {
        try reject("floating control must fit inside the viewport with margin")
      }
    case .scrollbar(let width):
      if width < 2 || width * 4 > config.crossAxisSize {
        try reject("scrollbar width must be in 2...crossAxisSize/4")
      }
    case .degraded(let maxDelta):
      if maxDelta < 1 || maxDelta > 2 {
        try reject("degraded maxChannelDelta must be 1 or 2 to stay a near-exact fixture")
      }
    default:
      break
    }
  }

  private static func fileID(_ index: Int) -> String {
    let number = index + 1
    return number < 10 ? "capture-00\(number)" : "capture-0\(number)"
  }

  private static func crop(
    _ image: RasterImage,
    startRow: Int,
    rowCount: Int
  ) throws -> RasterImage {
    let start = startRow * image.rowByteCount
    let end = (startRow + rowCount) * image.rowByteCount
    return try RasterImage(
      width: image.width,
      height: rowCount,
      pixels: Array(image.pixels[start..<end])
    )
  }

  private static func transpose(_ image: RasterImage) throws -> RasterImage {
    var pixels = [UInt8](repeating: 0, count: image.pixels.count)
    let channels = RasterImage.channelsPerPixel
    for y in 0..<image.height {
      for x in 0..<image.width {
        let sourceOffset = image.byteOffset(x: x, y: y)
        let targetOffset = ((x * image.height) + y) * channels
        for channel in 0..<channels {
          pixels[targetOffset + channel] = image.pixels[sourceOffset + channel]
        }
      }
    }
    return try RasterImage(width: image.height, height: image.width, pixels: pixels)
  }

  /// FNV-1a 64 over dimensions and raw RGBA bytes, rendered as 16 hex digits.
  static func fingerprint(_ image: RasterImage) -> String {
    var hash: UInt64 = 14_695_981_039_346_656_037
    let prime: UInt64 = 1_099_511_628_211
    func absorb(_ byte: UInt8) {
      hash ^= UInt64(byte)
      hash = hash &* prime
    }
    for value in [image.width, image.height] {
      for shift in stride(from: 0, to: 64, by: 8) {
        absorb(UInt8(truncatingIfNeeded: UInt64(bitPattern: Int64(value)) >> UInt64(shift)))
      }
    }
    for byte in image.pixels {
      absorb(byte)
    }
    let alphabet = Array("0123456789abcdef".utf8)
    var characters = [UInt8]()
    characters.reserveCapacity(16)
    for shift in stride(from: 60, through: 0, by: -4) {
      characters.append(alphabet[Int((hash >> UInt64(shift)) & 0xf)])
    }
    return "fnv1a64:" + String(decoding: characters, as: UTF8.self)
  }

  private static func mix(_ a: UInt64, _ b: UInt64) -> UInt64 {
    var z = a &+ 0x9E37_79B9_7F4A_7C15 &* (b &+ 1)
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
