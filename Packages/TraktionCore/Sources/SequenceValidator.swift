import TraktionDomain

/// Deterministic ingest validation against the Milestone 1 constraints.
/// Returns the first typed failure found, or nil when the sequence is valid.
public enum SequenceValidator {
    public static func validate(_ sequence: CaptureSequence) -> ReconstructionFailure? {
        guard sequence.axis == Milestone1Policy.supportedAxis else {
            return .unsupportedTransform(
                details: "axis \(sequence.axis.rawValue) is not supported in Milestone 1; only \(Milestone1Policy.supportedAxis.rawValue) reconstruction is implemented"
            )
        }

        let count = sequence.captures.count
        guard count >= Milestone1Policy.minimumCaptureCount,
              count <= Milestone1Policy.maximumCaptureCount else {
            return .invalidCaptureCount(
                found: count,
                minimum: Milestone1Policy.minimumCaptureCount,
                maximum: Milestone1Policy.maximumCaptureCount
            )
        }

        let expectedWidth = sequence.captures[0].pixelWidth
        for capture in sequence.captures {
            guard capture.pixelWidth == expectedWidth else {
                return .incompatibleDimensions(
                    assetID: capture.id,
                    expectedWidth: expectedWidth,
                    foundWidth: capture.pixelWidth
                )
            }
            guard capture.pixelWidth > 0, capture.pixelHeight > 0 else {
                return .unreadableAsset(
                    fileName: capture.fileName,
                    reason: "capture has empty pixel dimensions"
                )
            }
        }
        return nil
    }
}
