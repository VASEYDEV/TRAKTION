import FixtureForgeKit
import TraktionCore
import TraktionDomain

// Evaluation harness (docs/tasks/0004): runs the standard fixture corpus
// through the shipping engine and computes the EVALUATION.md metrics. The
// report is the objective record the Milestone 1 audit consumes; false-safe
// findings outrank everything else.

public struct EvaluationCase: Sendable {
  public let name: String
  public let configuration: FixtureControlConfiguration
  public let engineAxis: ReconstructionAxis

  public init(
    name: String,
    configuration: FixtureControlConfiguration,
    engineAxis: ReconstructionAxis = .vertical
  ) {
    self.name = name
    self.configuration = configuration
    self.engineAxis = engineAxis
  }
}

public enum EvaluationVerdict: String, Codable, Equatable, Sendable {
  /// Behavior matched ground truth (including correct registration).
  case pass
  /// The engine produced output where ground truth demands a failure, or
  /// produced a misregistered/mismatching composite. The severest class.
  case falseSafe = "false-safe"
  /// The engine failed where ground truth says reconstruction is possible.
  case falseWarning = "false-warning"
  /// The engine failed as required, but with a different typed code.
  case wrongFailure = "wrong-failure"
}

public struct EvaluationCaseResult: Codable, Equatable, Sendable {
  public let name: String
  public let expectedStatus: String
  public let expectedFailureCode: String?
  /// "reconstructed" or "failed".
  public let outcome: String
  public let failureCode: String?
  public let verdict: EvaluationVerdict
  /// Exact reconstructable cases only: decoded-pixel equality with the source.
  public let pixelEqualToSource: Bool?
  /// Reconstructable cases only, vs the source canvas row multiset.
  public let missingRows: Int?
  public let duplicatedRows: Int?
  /// Per joint, |found overlap − expected overlap|.
  public let registrationErrors: [Int]?
  /// Per joint, mean absolute channel difference between the two captures at
  /// the chosen seam row, normalized to 0...1.
  public let seamEnergies: [Double]?
  /// Two runs produced identical plans and pixels (or identical failures).
  public let deterministic: Bool
  public var milliseconds: Int
}

public struct EvaluationSummary: Codable, Equatable, Sendable {
  public let cases: Int
  public let pass: Int
  public let falseSafe: Int
  public let falseWarning: Int
  public let wrongFailure: Int
  public let nondeterministic: Int

  public var isAcceptable: Bool {
    falseSafe == 0 && falseWarning == 0 && wrongFailure == 0 && nondeterministic == 0
  }
}

public struct EvaluationReport: Codable, Equatable, Sendable {
  public let schemaVersion: Int
  public let generator: String
  public let summary: EvaluationSummary
  public var cases: [EvaluationCaseResult]
}

public enum EvaluationHarness {
  public static let generatorName = "traktion-lab evaluate v1"

  /// The corpus the Milestone 1 audit runs: every control-set variant, the
  /// 10–80% overlap sweep, and a horizontal-axis case. Seeds are fixed so the
  /// report is comparable run to run.
  public static func standardCorpus() -> [EvaluationCase] {
    var cases: [EvaluationCase] = []
    let variants: [(String, FixtureVariant)] = [
      ("baseline", .baseline),
      ("one-pixel-offset", .onePixelOffset),
      ("degraded", .degraded(maxChannelDelta: 2)),
      ("duplicate-capture", .duplicateCapture),
      ("reversed-order", .reversedOrder),
      ("missing-middle", .missingMiddle),
      ("sticky-header", .stickyHeader(rows: 12)),
      ("sticky-footer", .stickyFooter(rows: 12)),
      ("floating-control", .floatingControl(width: 14, height: 14)),
      ("scrollbar", .scrollbar(width: 4)),
    ]
    for (index, entry) in variants.enumerated() {
      cases.append(
        EvaluationCase(
          name: entry.0,
          configuration: FixtureControlConfiguration(
            sourceID: entry.0,
            seed: UInt64(1000 + index),
            variant: entry.1
          )
        )
      )
    }
    for percent in [10, 25, 50, 66, 80] {
      cases.append(
        EvaluationCase(
          name: "overlap-sweep-\(percent)",
          configuration: FixtureControlConfiguration(
            sourceID: "sweep-\(percent)",
            overlapLength: max(10, 96 * percent / 100),
            seed: UInt64(2000 + percent),
            variant: .baseline
          )
        )
      )
    }
    cases.append(
      EvaluationCase(
        name: "horizontal-baseline",
        configuration: FixtureControlConfiguration(
          sourceID: "horizontal",
          axis: .horizontal,
          seed: 3000,
          variant: .baseline
        ),
        engineAxis: .horizontal
      )
    )
    return cases
  }

  public static func evaluate(
    _ cases: [EvaluationCase] = standardCorpus(),
    settings: ReconstructionSettings = ReconstructionSettings()
  ) throws -> EvaluationReport {
    let engine = ReconstructionEngine(settings: settings)
    var results: [EvaluationCaseResult] = []
    results.reserveCapacity(cases.count)

    for evaluationCase in cases {
      let bundle = try FixtureControlGenerator.generate(evaluationCase.configuration)
      let sequence = CaptureSequence(captures: bundle.captures)

      let clock = ContinuousClock()
      let start = clock.now
      let first = run(engine, sequence, axis: evaluationCase.engineAxis)
      let elapsed = clock.now - start
      let second = run(engine, sequence, axis: evaluationCase.engineAxis)
      let deterministic = outcomesMatch(first, second)

      results.append(
        assess(
          name: evaluationCase.name,
          bundle: bundle,
          outcome: first,
          deterministic: deterministic,
          milliseconds: Int(elapsed.components.seconds) * 1000
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        )
      )
    }

    let summary = EvaluationSummary(
      cases: results.count,
      pass: results.filter { $0.verdict == .pass }.count,
      falseSafe: results.filter { $0.verdict == .falseSafe }.count,
      falseWarning: results.filter { $0.verdict == .falseWarning }.count,
      wrongFailure: results.filter { $0.verdict == .wrongFailure }.count,
      nondeterministic: results.filter { !$0.deterministic }.count
    )
    return EvaluationReport(
      schemaVersion: 1,
      generator: generatorName,
      summary: summary,
      cases: results
    )
  }

  // MARK: - Assessment

  enum RunOutcome {
    case reconstructed(ReconstructionResult)
    case failed(ReconstructionFailure)
    case unexpectedError(String)
  }

  private static func run(
    _ engine: ReconstructionEngine,
    _ sequence: CaptureSequence,
    axis: ReconstructionAxis
  ) -> RunOutcome {
    do {
      return .reconstructed(try engine.reconstruct(sequence, axis: axis))
    } catch let failure as ReconstructionFailure {
      return .failed(failure)
    } catch {
      return .unexpectedError(String(describing: error))
    }
  }

  private static func outcomesMatch(_ lhs: RunOutcome, _ rhs: RunOutcome) -> Bool {
    switch (lhs, rhs) {
    case (.reconstructed(let a), .reconstructed(let b)):
      return a.plan == b.plan && a.image == b.image
    case (.failed(let a), .failed(let b)):
      return a == b
    default:
      return false
    }
  }

  /// Verdict rules: ground truth is authoritative. A composite where a typed
  /// failure is required — or a composite with wrong registration or wrong
  /// pixels for an exact fixture — is a false-safe. A failure where
  /// reconstruction is required is a false-warning.
  static func assess(
    name: String,
    bundle: FixtureControlBundle,
    outcome: RunOutcome,
    deterministic: Bool,
    milliseconds: Int
  ) -> EvaluationCaseResult {
    let truth = bundle.groundTruth
    var pixelEqual: Bool?
    var missingRows: Int?
    var duplicatedRows: Int?
    var registrationErrors: [Int]?
    var seamEnergies: [Double]?
    let outcomeLabel: String
    var failureCode: String?
    let verdict: EvaluationVerdict

    switch outcome {
    case .reconstructed(let result):
      outcomeLabel = "reconstructed"
      if truth.expectedFailureCode != nil {
        verdict = .falseSafe
      } else {
        let errors = zip(result.plan.joints.map(\.overlapRows), truth.expectedOverlaps)
          .map { abs($0 - $1) }
        registrationErrors = errors
        seamEnergies = result.plan.joints.enumerated().map { index, joint in
          seamEnergy(
            preceding: bundle.captures[index].image,
            following: bundle.captures[index + 1].image,
            joint: joint
          )
        }
        let isExact = truth.expectedStatus == "reconstructable"
        if isExact {
          pixelEqual = result.image == bundle.source
          let rows = rowAccounting(source: bundle.source, composite: result.image)
          missingRows = rows.missing
          duplicatedRows = rows.duplicated
        }
        let misregistered = errors.contains { $0 != 0 }
          || result.plan.joints.count != truth.expectedOverlaps.count
        if misregistered || (isExact && pixelEqual != true) {
          verdict = .falseSafe
        } else {
          verdict = .pass
        }
      }
    case .failed(let failure):
      outcomeLabel = "failed"
      failureCode = failure.code
      if let expected = truth.expectedFailureCode {
        verdict = failure.code == expected ? .pass : .wrongFailure
      } else {
        verdict = .falseWarning
      }
    case .unexpectedError(let description):
      outcomeLabel = "failed"
      failureCode = "untyped:\(description)"
      verdict = truth.expectedFailureCode == nil ? .falseWarning : .wrongFailure
    }

    return EvaluationCaseResult(
      name: name,
      expectedStatus: truth.expectedStatus,
      expectedFailureCode: truth.expectedFailureCode,
      outcome: outcomeLabel,
      failureCode: failureCode,
      verdict: verdict,
      pixelEqualToSource: pixelEqual,
      missingRows: missingRows,
      duplicatedRows: duplicatedRows,
      registrationErrors: registrationErrors,
      seamEnergies: seamEnergies,
      deterministic: deterministic,
      milliseconds: milliseconds
    )
  }

  // MARK: - Metrics

  /// Missing = source rows absent from the composite (multiset deficit);
  /// duplicated = composite rows exceeding their source count. Zero/zero for
  /// a faithful exact reconstruction. Computed only for exact fixtures —
  /// variant overlays make near-exact composites differ from the pre-overlay
  /// source by design.
  static func rowAccounting(
    source: RasterImage,
    composite: RasterImage
  ) -> (missing: Int, duplicated: Int) {
    var sourceCounts: [[UInt8]: Int] = [:]
    for row in 0..<source.height {
      let start = row * source.rowByteCount
      sourceCounts[Array(source.pixels[start..<(start + source.rowByteCount)]), default: 0] += 1
    }
    var compositeCounts: [[UInt8]: Int] = [:]
    for row in 0..<composite.height {
      let start = row * composite.rowByteCount
      compositeCounts[
        Array(composite.pixels[start..<(start + composite.rowByteCount)]), default: 0
      ] += 1
    }

    var missing = 0
    for (row, count) in sourceCounts {
      missing += max(0, count - (compositeCounts[row] ?? 0))
    }
    var duplicated = 0
    for (row, count) in compositeCounts {
      duplicated += max(0, count - (sourceCounts[row] ?? 0))
    }
    return (missing, duplicated)
  }

  /// Mean absolute channel difference between the two captures at the chosen
  /// seam row of the overlap, normalized to 0...1. Zero at an exact seam.
  static func seamEnergy(
    preceding: RasterImage,
    following: RasterImage,
    joint: JointDiagnosis
  ) -> Double {
    let seamRow = min(joint.seamRowInOverlap, joint.overlapRows - 1)
    let precedingRow = preceding.height - joint.overlapRows + seamRow
    var difference = 0
    for column in 0..<preceding.width {
      let precedingOffset = preceding.byteOffset(x: column, y: precedingRow)
      let followingOffset = following.byteOffset(x: column, y: seamRow)
      for channel in 0..<RasterImage.channelsPerPixel {
        difference += abs(
          Int(preceding.pixels[precedingOffset + channel])
            - Int(following.pixels[followingOffset + channel])
        )
      }
    }
    let denominator = Double(preceding.width * RasterImage.channelsPerPixel) * 255
    return Double(difference) / denominator
  }
}
