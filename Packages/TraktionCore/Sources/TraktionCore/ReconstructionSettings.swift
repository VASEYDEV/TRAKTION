public struct ReconstructionSettings: Equatable, Sendable {
  public let minimumOverlapRows: Int
  public let maximumNormalizedMeanAbsoluteError: Double
  public let maximumChangedPixelFraction: Double
  public let changedChannelThreshold: UInt8
  public let sampledRows: Int
  public let sampledColumns: Int
  /// Adaptive verification (docs/adr/ADR-013). 1 disables it — the original
  /// single-pass sampling algorithm; 2 or more adds the early-exit full-width
  /// verification pass over surviving candidates (values above 2 behave the
  /// same), spending from the same sample budget.
  public let refinementRounds: Int
  public let candidateLimit: Int
  public let maximumCapturePixels: Int
  public let maximumTotalInputPixels: Int
  public let maximumOutputPixels: Int
  public let maximumOverlapSearchRows: Int
  public let maximumSampleComparisonsPerJoint: Int
  public let maximumFullComparisonPixelsPerJoint: Int

  public init(
    minimumOverlapRows: Int = 8,
    maximumNormalizedMeanAbsoluteError: Double = 0.01,
    maximumChangedPixelFraction: Double = 0.02,
    changedChannelThreshold: UInt8 = 4,
    sampledRows: Int = 24,
    sampledColumns: Int = 64,
    refinementRounds: Int = 3,
    candidateLimit: Int = 12,
    maximumCapturePixels: Int = 16_777_216,
    maximumTotalInputPixels: Int = 67_108_864,
    maximumOutputPixels: Int = 67_108_864,
    maximumOverlapSearchRows: Int = 16_384,
    // Calibrated for phone-scale captures (docs/tasks/0005, ADR-013): a
    // 1170x2532 pair costs ~4M comparisons in the sparse first pass; the
    // early-exit verification pass prunes each wrong candidate after a few
    // percent of its area, measured at ~100M comparisons total for that
    // scale. 128M leaves headroom. Full verification of a saturated
    // candidate set (candidateLimit x 2532 rows x 1170 px) needs ~36M.
    maximumSampleComparisonsPerJoint: Int = 134_217_728,
    maximumFullComparisonPixelsPerJoint: Int = 67_108_864
  ) {
    self.minimumOverlapRows = max(1, minimumOverlapRows)
    self.maximumNormalizedMeanAbsoluteError = max(
      0,
      maximumNormalizedMeanAbsoluteError
    )
    self.maximumChangedPixelFraction = max(0, maximumChangedPixelFraction)
    self.changedChannelThreshold = changedChannelThreshold
    self.sampledRows = max(2, sampledRows)
    self.sampledColumns = max(2, sampledColumns)
    self.refinementRounds = max(1, refinementRounds)
    self.candidateLimit = max(2, candidateLimit)
    self.maximumCapturePixels = max(1, maximumCapturePixels)
    self.maximumTotalInputPixels = max(1, maximumTotalInputPixels)
    self.maximumOutputPixels = max(1, maximumOutputPixels)
    self.maximumOverlapSearchRows = max(1, maximumOverlapSearchRows)
    self.maximumSampleComparisonsPerJoint = max(
      1,
      maximumSampleComparisonsPerJoint
    )
    self.maximumFullComparisonPixelsPerJoint = max(
      1,
      maximumFullComparisonPixelsPerJoint
    )
  }
}
