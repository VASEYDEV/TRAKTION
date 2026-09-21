import TraktionDomain

public enum ProjectRestorationFailure: Error, Equatable, Sendable {
  case invalidEvidence
  case cancelled
}

/// Automatic pixels and committed editing metadata verified from the same originals.
public struct RestoredProjectReconstruction: Sendable {
  public let result: ReconstructionResult
  public let document: SeamEditingDocument
}

/// Core owns replay and evidence acceptance; callers own file formats, decoding,
/// admission and publication. Saved metadata never substitutes for reconstruction.
public struct ProjectRestorer: Sendable {
  public init() {}

  public func restore(
    captures: [CaptureAsset],
    automaticPlan: ReconstructionPlan,
    committedPlan: ReconstructionPlan,
    isCancelled: @Sendable () -> Bool = { false }
  ) throws -> RestoredProjectReconstruction {
    guard !isCancelled() else { throw ProjectRestorationFailure.cancelled }
    let result: ReconstructionResult
    do {
      result = try ReconstructionEngine().reconstruct(
        CaptureSequence(captures: captures), axis: .vertical
      )
    } catch { throw ProjectRestorationFailure.invalidEvidence }
    // The synchronous engine does not interrupt itself. Keep its worker slot
    // occupied until it returns, then reject cancellation before accepting plans.
    guard !isCancelled() else { throw ProjectRestorationFailure.cancelled }
    guard result.plan == automaticPlan else { throw ProjectRestorationFailure.invalidEvidence }
    let document: SeamEditingDocument
    do {
      document = try SeamEditingDocument(originalPlan: result.plan,
        committedPlan: committedPlan, captures: captures)
    } catch { throw ProjectRestorationFailure.invalidEvidence }
    return RestoredProjectReconstruction(result: result, document: document)
  }
}
