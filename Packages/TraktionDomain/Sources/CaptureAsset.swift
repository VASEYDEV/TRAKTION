/// An ingested source capture. Describes the original asset; never a mutation
/// of it. Identifiers are stable for the lifetime of a reconstruction project.
public struct CaptureAsset: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let fileName: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let byteCount: Int
    /// Lowercase hex SHA-256 of the original file bytes.
    public let sha256: String

    public init(
        id: String,
        fileName: String,
        pixelWidth: Int,
        pixelHeight: Int,
        byteCount: Int,
        sha256: String
    ) {
        self.id = id
        self.fileName = fileName
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.sha256 = sha256
    }
}
