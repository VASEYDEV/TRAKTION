/// Machine-readable manifest emitted by TraktionLab as a `*.reconstruction.json`
/// sidecar. This is the durable diagnostic record of a pipeline run; it must be
/// deterministic for identical inputs, so it carries no wall-clock timestamps.
public struct ReconstructionManifest: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Equatable, Sendable {
        /// Assets were loaded and passed Milestone 1 ingest validation.
        case ingested
        /// The pipeline stopped with the typed failure recorded in `failure`.
        case failed
    }

    public let formatVersion: Int
    /// Producing tool and version, e.g. "traktion-lab 0.1.0".
    public let generator: String
    public let axis: ReconstructionAxis
    public let status: Status
    public let captures: [CaptureAsset]
    public let failure: ReconstructionFailure?

    public init(
        formatVersion: Int = 1,
        generator: String,
        axis: ReconstructionAxis,
        status: Status,
        captures: [CaptureAsset],
        failure: ReconstructionFailure? = nil
    ) {
        self.formatVersion = formatVersion
        self.generator = generator
        self.axis = axis
        self.status = status
        self.captures = captures
        self.failure = failure
    }
}
