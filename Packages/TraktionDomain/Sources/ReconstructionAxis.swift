/// The axis along which a capture sequence is reconstructed.
///
/// Milestone 1 implements vertical reconstruction only; `horizontal` exists so
/// that manifests and tools can represent the request and reject it with a
/// typed failure instead of silently ignoring it.
public enum ReconstructionAxis: String, Codable, Equatable, Sendable, CaseIterable {
    case vertical
    case horizontal
}
