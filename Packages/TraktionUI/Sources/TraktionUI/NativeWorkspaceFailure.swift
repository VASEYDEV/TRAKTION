import TraktionDomain
import TraktionVision

public enum NativeWorkspaceFailure: Error, Equatable, Sendable {
  case importFailure(PNGImportFailure)
  case reconstruction(ReconstructionFailure)
  case selection(String)
  case unexpected

  public func message(captures: [CaptureAsset]) -> String {
    func name(_ id: CaptureID) -> String {
      guard let index = captures.firstIndex(where: { $0.id == id }) else {
        return "the selected capture"
      }
      return "\(index + 1). \(captures[index].sourceName)"
    }

    switch self {
    case .importFailure(.cleanupFailed):
      return PNGImportFailure.cleanupFailed.description
    case .importFailure(let error):
      return "Import failed. Your current captures were kept. \(error)"
    case .selection(let detail):
      return "Could not open the selection. \(detail)"
    case .unexpected:
      return "The operation could not finish. Your original files are unchanged."
    case .reconstruction(let error):
      switch error {
      case .duplicateCapture(let preceding, let following):
        return "\(name(preceding)) and \(name(following)) are the same image. Remove one copy."
      case .incompatibleDimensions(let expected, let actual, let id):
        return "\(name(id)) is \(actual) px wide; the other captures are \(expected) px wide."
      case .insufficientOverlap(let preceding, let following, _):
        return "No reliable overlap was found between \(name(preceding)) and \(name(following)). Check their order or add the missing capture."
      case .ambiguousOverlap(let preceding, let following, _),
        .ambiguousOverlapDirection(let preceding, let following, _, _):
        return "The overlap between \(name(preceding)) and \(name(following)) is uncertain. Check their order or choose captures with clearer overlap."
      case .repeatedInterfaceArtifact(let preceding, let following, _):
        return "\(name(preceding)) and \(name(following)) repeat a fixed interface band. This pair cannot be reconstructed safely."
      case .captureCountOutOfRange:
        return "Choose between 2 and 10 captures before reconstructing."
      case .resourceLimitExceeded:
        return "This batch exceeds the reconstruction budget. Remove a capture or choose smaller PNGs."
      case .sequenceOrderNotFound:
        return "The captures do not establish a complete sequence. Check their order and coverage."
      case .ambiguousSequenceOrder:
        return "More than one capture order is plausible. Confirm a sequence with clearer overlap."
      case .unsupportedAxis:
        return "This workflow currently supports vertical reconstruction."
      case .outputDimensionsOverflow, .invalidPlan:
        return "A safe reconstruction could not be produced. Your captures are unchanged."
      }
    }
  }
}
