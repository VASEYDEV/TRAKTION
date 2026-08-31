/// An ordered set of captures supplied for reconstruction along one axis.
/// Milestone 1 assumes the supplied order is the intended order.
public struct CaptureSequence: Codable, Equatable, Sendable {
    public let axis: ReconstructionAxis
    public let captures: [CaptureAsset]

    public init(axis: ReconstructionAxis, captures: [CaptureAsset]) {
        self.axis = axis
        self.captures = captures
    }
}
