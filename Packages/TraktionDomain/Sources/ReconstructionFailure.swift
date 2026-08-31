/// Typed reconstruction failures (RECONSTRUCTION_SPEC.md failure policy).
/// TRAKTION never converts these into a silently "successful" result.
public enum ReconstructionFailure: Error, Codable, Equatable, Sendable {
    /// Adjacent captures share less overlap than the engine can register.
    case insufficientOverlap(jointIndex: Int)
    /// Coverage between adjacent captures is missing; nothing may be bridged.
    case missingCoverage(jointIndex: Int)
    /// A capture's dimensions are incompatible with the sequence.
    case incompatibleDimensions(assetID: String, expectedWidth: Int, foundWidth: Int)
    /// Content changed between captures in a way that prevents a single truth.
    case dynamicConflict(jointIndex: Int)
    /// The capture order cannot be established with confidence.
    case ambiguousOrder
    /// The request requires a transform or mode outside the supported set.
    case unsupportedTransform(details: String)
    /// The number of captures is outside the supported range.
    case invalidCaptureCount(found: Int, minimum: Int, maximum: Int)
    /// A source asset could not be read or decoded. Sources are never repaired
    /// or substituted.
    case unreadableAsset(fileName: String, reason: String)
}

extension ReconstructionFailure: CustomStringConvertible {
    public var description: String {
        switch self {
        case .insufficientOverlap(let joint):
            return "insufficient overlap at joint \(joint)"
        case .missingCoverage(let joint):
            return "missing coverage at joint \(joint)"
        case .incompatibleDimensions(let assetID, let expected, let found):
            return "incompatible dimensions for \(assetID): expected width \(expected), found \(found)"
        case .dynamicConflict(let joint):
            return "dynamic content conflict at joint \(joint)"
        case .ambiguousOrder:
            return "capture order is ambiguous"
        case .unsupportedTransform(let details):
            return "unsupported transform: \(details)"
        case .invalidCaptureCount(let found, let minimum, let maximum):
            return "invalid capture count \(found): supported range is \(minimum)-\(maximum)"
        case .unreadableAsset(let fileName, let reason):
            return "unreadable asset \(fileName): \(reason)"
        }
    }
}
