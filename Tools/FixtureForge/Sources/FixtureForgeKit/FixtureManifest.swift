import TraktionDomain

/// Ground truth for a generated fixture set, written as `fixture.json` next to
/// the capture PNGs. Tests treat this record as the objective truth a
/// reconstruction must match.
public struct FixtureManifest: Codable, Equatable, Sendable {
    public struct Capture: Codable, Equatable, Sendable {
        public let id: String
        public let fileName: String
        /// Origin of this capture inside the source canvas (top row for
        /// vertical fixtures).
        public let originY: Int
        public let pixelWidth: Int
        public let pixelHeight: Int
        public let expectedOrderIndex: Int
        /// Lowercase hex SHA-256 of the capture PNG bytes.
        public let sha256: String

        public init(
            id: String,
            fileName: String,
            originY: Int,
            pixelWidth: Int,
            pixelHeight: Int,
            expectedOrderIndex: Int,
            sha256: String
        ) {
            self.id = id
            self.fileName = fileName
            self.originY = originY
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.expectedOrderIndex = expectedOrderIndex
            self.sha256 = sha256
        }
    }

    public let formatVersion: Int
    public let sourceID: String
    public let axis: ReconstructionAxis
    public let seed: UInt64
    public let sourceWidth: Int
    public let sourceHeight: Int
    public let sourceFileName: String
    /// Lowercase hex SHA-256 of the source canvas PNG bytes.
    public let sourceSHA256: String
    public let captures: [Capture]
    /// Overlap rows between consecutive captures (count == captures.count - 1).
    public let expectedOverlaps: [Int]
    /// What a correct pipeline should conclude, e.g. "reconstructable".
    public let expectedStatus: String

    public init(
        formatVersion: Int = 1,
        sourceID: String,
        axis: ReconstructionAxis,
        seed: UInt64,
        sourceWidth: Int,
        sourceHeight: Int,
        sourceFileName: String,
        sourceSHA256: String,
        captures: [Capture],
        expectedOverlaps: [Int],
        expectedStatus: String
    ) {
        self.formatVersion = formatVersion
        self.sourceID = sourceID
        self.axis = axis
        self.seed = seed
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.sourceFileName = sourceFileName
        self.sourceSHA256 = sourceSHA256
        self.captures = captures
        self.expectedOverlaps = expectedOverlaps
        self.expectedStatus = expectedStatus
    }
}
