import TraktionDomain

/// Hard constraints for Milestone 1 (AGENTS.md "Initial implementation
/// constraints"): vertical stitching only, 2-10 captures, identical pixel
/// width, supplied sequence order, PNG input, static content.
public enum Milestone1Policy {
    public static let minimumCaptureCount = 2
    public static let maximumCaptureCount = 10
    public static let supportedAxis: ReconstructionAxis = .vertical
}
