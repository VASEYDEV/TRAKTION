/// Confidence classification for a single joint between adjacent captures
/// (RECONSTRUCTION_SPEC.md §8).
public enum JointConfidence: String, Codable, Equatable, Sendable, CaseIterable {
    case exact
    case strong
    case review
    case gap
    case conflict
}
