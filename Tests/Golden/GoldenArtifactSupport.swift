import Foundation
import TraktionDomain
import TraktionLabEvaluation
import XCTest

struct GoldenArtifactRecord {
  let caseName: String
  let expected: RasterImage
  let captures: [CaptureAsset]
  let outcome: SyntheticArtifactOutcome

  func writeIfFailed(_ failed: Bool, directory: URL?) throws {
    guard failed, let directory else { return }
    try SyntheticArtifactWriter.write(
      caseName: caseName, expected: expected, captures: captures,
      outcome: outcome, directory: directory
    )
  }
}

/// Keeps synthetic evidence until XCTest knows whether any assertion failed,
/// including plan, confidence, ordering, and determinism assertions. Failure
/// rasters are retained only when the engine actually produced them.
class GoldenArtifactTestCase: XCTestCase {
  private var records: [GoldenArtifactRecord] = []
  private var evaluationRuns = 0

  private var artifactDirectory: URL? {
    guard let path = ProcessInfo.processInfo.environment["TRAKTION_GOLDEN_ARTIFACTS"],
      !path.isEmpty
    else { return nil }
    return URL(fileURLWithPath: path, isDirectory: true)
  }

  func goldenReconstruct(
    expected: RasterImage,
    captures: [CaptureAsset],
    _ operation: () throws -> ReconstructionResult
  ) throws -> ReconstructionResult {
    func retain(_ outcome: SyntheticArtifactOutcome) {
      guard artifactDirectory != nil else { return }
      let allowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
      let testName = String(
        String.UnicodeScalarView(
          name.unicodeScalars.map {
            allowed.contains($0) ? $0 : UnicodeScalar("-")
          }))
      records.append(
        GoldenArtifactRecord(
          caseName: "\(testName)-\(records.count + 1)",
          expected: expected, captures: captures, outcome: outcome
        )
      )
    }
    do {
      let result = try operation()
      retain(.reconstructed(result))
      return result
    } catch let error as ReconstructionFailure {
      retain(.failed(error))
      throw error
    } catch {
      retain(.unexpectedError(String(describing: error)))
      throw error
    }
  }

  func evaluationArtifacts(function: String = #function) -> EvaluationArtifactOptions? {
    guard let artifactDirectory else { return nil }
    evaluationRuns += 1
    let functionName = function.prefix { $0 != "(" }
    return EvaluationArtifactOptions(
      directory: artifactDirectory.appendingPathComponent(
        "evaluation-\(functionName)-\(evaluationRuns)")
    )
  }

  override func tearDownWithError() throws {
    defer { records.removeAll() }
    try super.tearDownWithError()
    let failed = (testRun?.totalFailureCount ?? 0) > 0
    for record in records {
      try record.writeIfFailed(
        failed, directory: artifactDirectory?.appendingPathComponent("golden"))
    }
  }
}
