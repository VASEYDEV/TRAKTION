import FixtureForgeKit
import TraktionCore
import TraktionDomain

// Evaluation harness (docs/tasks/0004, extended by docs/tasks/0008): runs the
// standard fixture corpus through the shipping engine and computes the
// EVALUATION.md metrics. The report is the objective record the milestone
// audits consume; false-safe findings outrank everything else.

/// How the Lab and the harness hand captures to the engine. `supplied` is the
/// Milestone 1 contract; `exact` recovers the order from byte-exact
/// suffix/prefix evidence only (task 0007, ADR-014); `nearExact` recovers it
/// from uniquely registered near-exact overlaps under the same global
/// uniqueness rule (task 0009, ADR-015). Both fail closed on gaps or
/// ambiguity.
public enum OrderPolicy: String, Codable, Equatable, Sendable, CaseIterable {
  case supplied
  case exact
  case nearExact = "near-exact"
}

public struct EvaluationCase: Sendable {
  public let name: String
  public let configuration: FixtureControlConfiguration
  public let engineAxis: ReconstructionAxis
  /// Non-nil turns this into an ordering case (docs/tasks/0008): the generated
  /// captures are permuted, the engine runs under the case's order policy,
  /// and the ordering expectation replaces the supplied-order ground-truth pin.
  public let ordering: OrderingCase?

  public init(
    name: String,
    configuration: FixtureControlConfiguration,
    engineAxis: ReconstructionAxis = .vertical,
    ordering: OrderingCase? = nil
  ) {
    self.name = name
    self.configuration = configuration
    self.engineAxis = engineAxis
    self.ordering = ordering
  }

  public var orderPolicy: OrderPolicy {
    ordering?.policy ?? .supplied
  }
}

public struct OrderingCase: Sendable {
  /// Applied to the generated captures (indices into the generator's supplied
  /// order) before the run. Must be a permutation of `0..<captureCount`.
  public let permutation: [Int]
  public let expected: ExpectedOrderingOutcome
  /// The ordering policy the engine runs under; never `supplied`.
  public let policy: OrderPolicy

  public init(
    permutation: [Int],
    expected: ExpectedOrderingOutcome,
    policy: OrderPolicy = .exact
  ) {
    self.permutation = permutation
    self.expected = expected
    self.policy = policy == .supplied ? .exact : policy
  }
}

public enum ExpectedOrderingOutcome: Sendable {
  /// The engine must reconstruct, and the recovered order must equal the
  /// ground-truth documentary order.
  case reconstruct
  case fail(code: String)
}

public enum EvaluationVerdict: String, Codable, Equatable, Sendable {
  /// Behavior matched ground truth (including correct registration).
  case pass
  /// The engine produced output where ground truth demands a failure, or
  /// produced a misregistered/mismatching composite, or recovered an order
  /// that differs from the documentary order. The severest class.
  case falseSafe = "false-safe"
  /// The engine failed where ground truth says reconstruction is possible.
  case falseWarning = "false-warning"
  /// The engine failed as required, but with a different typed code.
  case wrongFailure = "wrong-failure"
}

public struct EvaluationCaseResult: Codable, Equatable, Sendable {
  public let name: String
  public let orderPolicy: OrderPolicy
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
  /// Ordering cases that reconstructed: capture IDs in recovered order.
  public let recoveredOrder: [String]?
  /// Two runs produced identical plans, pixels, and recovered orders (or
  /// identical failures).
  public let deterministic: Bool
  public var milliseconds: Int
}

/// EVALUATION.md "Ordering" metrics over the ordering cases of a report.
/// Sequence cases are those whose fixture has a documentary order (everything
/// except duplicate and missing-coverage controls); a pinned exact-only
/// refusal on such a case counts against the correct-sequence rate even
/// though its verdict is `pass` — the report records capability as well as
/// contract conformance.
public struct OrderingSummary: Codable, Equatable, Sendable {
  public let cases: Int
  public let sequencesExpected: Int
  public let sequencesCorrect: Int
  public let duplicatesExpected: Int
  public let duplicatesIdentified: Int
  public let missingCapturesExpected: Int
  public let missingCapturesDetected: Int
  /// Nil when the corresponding denominator is zero.
  public let correctSequenceRate: Double?
  public let duplicateIdentificationRate: Double?
  public let missingCaptureDetectionRate: Double?

  public init(
    cases: Int,
    sequencesExpected: Int,
    sequencesCorrect: Int,
    duplicatesExpected: Int,
    duplicatesIdentified: Int,
    missingCapturesExpected: Int,
    missingCapturesDetected: Int
  ) {
    self.cases = cases
    self.sequencesExpected = sequencesExpected
    self.sequencesCorrect = sequencesCorrect
    self.duplicatesExpected = duplicatesExpected
    self.duplicatesIdentified = duplicatesIdentified
    self.missingCapturesExpected = missingCapturesExpected
    self.missingCapturesDetected = missingCapturesDetected
    self.correctSequenceRate = Self.rate(sequencesCorrect, of: sequencesExpected)
    self.duplicateIdentificationRate = Self.rate(duplicatesIdentified, of: duplicatesExpected)
    self.missingCaptureDetectionRate = Self.rate(
      missingCapturesDetected,
      of: missingCapturesExpected
    )
  }

  private static func rate(_ numerator: Int, of denominator: Int) -> Double? {
    denominator == 0 ? nil : Double(numerator) / Double(denominator)
  }
}

public struct EvaluationSummary: Codable, Equatable, Sendable {
  public let cases: Int
  public let pass: Int
  public let falseSafe: Int
  public let falseWarning: Int
  public let wrongFailure: Int
  public let nondeterministic: Int
  public let ordering: OrderingSummary

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
  public static let generatorName = "traktion-lab evaluate v2"

  /// The corpus the milestone audits run: every control-set variant, the
  /// 10–80% overlap sweep, a horizontal-axis case, and the exact-ordering
  /// cases. Seeds and permutations are fixed so the report is comparable run
  /// to run.
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

    // Exact-ordering cases (docs/tasks/0008, ADR-014). Recovery must reproduce
    // the ground-truth documentary order or refuse with the pinned code; a
    // recovered order that differs from the documentary order is a false-safe.
    cases.append(
      EvaluationCase(
        name: "order-shuffled-baseline",
        configuration: FixtureControlConfiguration(
          sourceID: "order-shuffled",
          captureCount: 5,
          seed: 4000,
          variant: .baseline
        ),
        ordering: OrderingCase(permutation: [2, 4, 0, 3, 1], expected: .reconstruct)
      )
    )
    cases.append(
      EvaluationCase(
        name: "order-reversed",
        configuration: FixtureControlConfiguration(
          sourceID: "order-reversed",
          seed: 4001,
          variant: .reversedOrder
        ),
        ordering: OrderingCase(permutation: [0, 1, 2], expected: .reconstruct)
      )
    )
    cases.append(
      EvaluationCase(
        name: "order-missing-middle",
        configuration: FixtureControlConfiguration(
          sourceID: "order-missing-middle",
          seed: 4002,
          variant: .missingMiddle
        ),
        ordering: OrderingCase(
          permutation: [1, 0],
          expected: .fail(code: "sequenceOrderNotFound")
        )
      )
    )
    cases.append(
      EvaluationCase(
        name: "order-duplicate-capture",
        configuration: FixtureControlConfiguration(
          sourceID: "order-duplicate",
          seed: 4003,
          variant: .duplicateCapture
        ),
        ordering: OrderingCase(
          permutation: [3, 1, 0, 2],
          expected: .fail(code: "duplicateCapture")
        )
      )
    )
    // Near-exact ordering cases (docs/tasks/0009, ADR-015): uniquely
    // registered near-exact overlaps order captures the exact policy cannot
    // (the degraded control), exact input still orders, and a coverage gap
    // still refuses.
    cases.append(
      EvaluationCase(
        name: "order-near-exact-degraded",
        configuration: FixtureControlConfiguration(
          sourceID: "order-degraded",
          seed: 4004,
          variant: .degraded(maxChannelDelta: 2)
        ),
        ordering: OrderingCase(
          permutation: [1, 2, 0],
          expected: .reconstruct,
          policy: .nearExact
        )
      )
    )
    cases.append(
      EvaluationCase(
        name: "order-near-exact-shuffled-baseline",
        configuration: FixtureControlConfiguration(
          sourceID: "order-near-exact-shuffled",
          captureCount: 5,
          seed: 4005,
          variant: .baseline
        ),
        ordering: OrderingCase(
          permutation: [3, 0, 4, 1, 2],
          expected: .reconstruct,
          policy: .nearExact
        )
      )
    )
    cases.append(
      EvaluationCase(
        name: "order-near-exact-missing-middle",
        configuration: FixtureControlConfiguration(
          sourceID: "order-near-exact-missing",
          seed: 4006,
          variant: .missingMiddle
        ),
        ordering: OrderingCase(
          permutation: [1, 0],
          expected: .fail(code: "sequenceOrderNotFound"),
          policy: .nearExact
        )
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
      let captures = try inputCaptures(for: evaluationCase, bundle: bundle)

      let clock = ContinuousClock()
      let start = clock.now
      let first = run(
        engine,
        captures,
        axis: evaluationCase.engineAxis,
        policy: evaluationCase.orderPolicy
      )
      let elapsed = clock.now - start
      let second = run(
        engine,
        captures,
        axis: evaluationCase.engineAxis,
        policy: evaluationCase.orderPolicy
      )
      let deterministic = outcomesMatch(first.outcome, second.outcome)
        && first.recoveredOrder == second.recoveredOrder

      results.append(
        assess(
          name: evaluationCase.name,
          bundle: bundle,
          outcome: first.outcome,
          ordering: evaluationCase.ordering,
          recoveredOrder: first.recoveredOrder,
          deterministic: deterministic,
          milliseconds: Int(elapsed.components.seconds) * 1000
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        )
      )
    }

    return EvaluationReport(
      schemaVersion: 2,
      generator: generatorName,
      summary: summarize(results),
      cases: results
    )
  }

  static func summarize(_ results: [EvaluationCaseResult]) -> EvaluationSummary {
    EvaluationSummary(
      cases: results.count,
      pass: results.filter { $0.verdict == .pass }.count,
      falseSafe: results.filter { $0.verdict == .falseSafe }.count,
      falseWarning: results.filter { $0.verdict == .falseWarning }.count,
      wrongFailure: results.filter { $0.verdict == .wrongFailure }.count,
      nondeterministic: results.filter { !$0.deterministic }.count,
      ordering: orderingSummary(results)
    )
  }

  /// Ordering classes come from the fixture's semantic status: duplicate and
  /// missing-coverage controls test detection; every other ordering case has
  /// a documentary order the engine is expected to recover.
  static func orderingSummary(_ results: [EvaluationCaseResult]) -> OrderingSummary {
    let ordering = results.filter { $0.orderPolicy != .supplied }
    let duplicates = ordering.filter { $0.expectedStatus == "duplicate-capture" }
    let missing = ordering.filter { $0.expectedStatus == "missing-coverage" }
    let sequences = ordering.filter {
      $0.expectedStatus != "duplicate-capture" && $0.expectedStatus != "missing-coverage"
    }
    return OrderingSummary(
      cases: ordering.count,
      sequencesExpected: sequences.count,
      sequencesCorrect: sequences.filter {
        $0.verdict == .pass && $0.outcome == "reconstructed" && $0.recoveredOrder != nil
      }.count,
      duplicatesExpected: duplicates.count,
      duplicatesIdentified: duplicates.filter { $0.failureCode == "duplicateCapture" }.count,
      missingCapturesExpected: missing.count,
      missingCapturesDetected: missing.filter {
        $0.failureCode == "sequenceOrderNotFound"
      }.count
    )
  }

  // MARK: - Assessment

  enum RunOutcome {
    case reconstructed(ReconstructionResult)
    case failed(ReconstructionFailure)
    case unexpectedError(String)
  }

  public enum EvaluationCaseError: Error, Equatable, Sendable {
    /// The ordering permutation does not enumerate every generated capture
    /// exactly once.
    case invalidPermutation(caseName: String, permutation: [Int], captureCount: Int)
  }

  private static func inputCaptures(
    for evaluationCase: EvaluationCase,
    bundle: FixtureControlBundle
  ) throws -> [CaptureAsset] {
    guard let ordering = evaluationCase.ordering else {
      return bundle.captures
    }
    let count = bundle.captures.count
    guard ordering.permutation.count == count,
      Set(ordering.permutation) == Set(0..<count)
    else {
      throw EvaluationCaseError.invalidPermutation(
        caseName: evaluationCase.name,
        permutation: ordering.permutation,
        captureCount: count
      )
    }
    return ordering.permutation.map { bundle.captures[$0] }
  }

  private static func run(
    _ engine: ReconstructionEngine,
    _ captures: [CaptureAsset],
    axis: ReconstructionAxis,
    policy: OrderPolicy
  ) -> (outcome: RunOutcome, recoveredOrder: [CaptureID]?) {
    do {
      switch policy {
      case .supplied:
        let result = try engine.reconstruct(CaptureSequence(captures: captures), axis: axis)
        return (.reconstructed(result), nil)
      case .exact:
        let result = try engine.reconstructExactUnordered(captures, axis: axis)
        return (.reconstructed(result), result.plan.placements.map(\.captureID))
      case .nearExact:
        let result = try engine.reconstructNearExactUnordered(captures, axis: axis)
        return (.reconstructed(result), result.plan.placements.map(\.captureID))
      }
    } catch let failure as ReconstructionFailure {
      return (.failed(failure), nil)
    } catch {
      return (.unexpectedError(String(describing: error)), nil)
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
  /// pixels for an exact fixture, or a recovered order that differs from the
  /// documentary order — is a false-safe. A failure where reconstruction is
  /// required is a false-warning. For ordering cases the ordering expectation
  /// replaces the supplied-order ground-truth pin.
  static func assess(
    name: String,
    bundle: FixtureControlBundle,
    outcome: RunOutcome,
    ordering: OrderingCase? = nil,
    recoveredOrder: [CaptureID]? = nil,
    deterministic: Bool,
    milliseconds: Int
  ) -> EvaluationCaseResult {
    let truth = bundle.groundTruth
    let policy = ordering?.policy ?? OrderPolicy.supplied
    let expectedFailureCode: String?
    switch ordering?.expected {
    case .none:
      expectedFailureCode = truth.expectedFailureCode
    case .reconstruct:
      expectedFailureCode = nil
    case .fail(let code):
      expectedFailureCode = code
    }
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
      if expectedFailureCode != nil {
        verdict = .falseSafe
      } else if ordering != nil, recoveredOrder?.map(\.rawValue) != truth.expectedOrder {
        verdict = .falseSafe
      } else {
        // Captures in the order the plan placed them; supplied order for the
        // Milestone 1 path, the recovered order for ordering cases.
        let placed = capturesInPlanOrder(bundle: bundle, plan: result.plan)
        let expectedOverlaps = ordering == nil
          ? truth.expectedOverlaps
          : documentOrderOverlaps(truth)
        let errors = zip(result.plan.joints.map(\.overlapRows), expectedOverlaps)
          .map { abs($0 - $1) }
        registrationErrors = errors
        seamEnergies = placed.map { placedCaptures in
          result.plan.joints.enumerated().map { index, joint in
            seamEnergy(
              preceding: placedCaptures[index].image,
              following: placedCaptures[index + 1].image,
              joint: joint
            )
          }
        }
        let isExact = ["reconstructable", "reversed-order"].contains(truth.expectedStatus)
        if isExact {
          pixelEqual = result.image == bundle.source
          let rows = rowAccounting(source: bundle.source, composite: result.image)
          missingRows = rows.missing
          duplicatedRows = rows.duplicated
        }
        let misregistered = errors.contains { $0 != 0 }
          || result.plan.joints.count != expectedOverlaps.count
          || placed == nil
        if misregistered || (isExact && pixelEqual != true) {
          verdict = .falseSafe
        } else {
          verdict = .pass
        }
      }
    case .failed(let failure):
      outcomeLabel = "failed"
      failureCode = failure.code
      if let expected = expectedFailureCode {
        verdict = failure.code == expected ? .pass : .wrongFailure
      } else {
        verdict = .falseWarning
      }
    case .unexpectedError(let description):
      outcomeLabel = "failed"
      failureCode = "untyped:\(description)"
      verdict = expectedFailureCode == nil ? .falseWarning : .wrongFailure
    }

    return EvaluationCaseResult(
      name: name,
      orderPolicy: policy,
      expectedStatus: truth.expectedStatus,
      expectedFailureCode: expectedFailureCode,
      outcome: outcomeLabel,
      failureCode: failureCode,
      verdict: verdict,
      pixelEqualToSource: pixelEqual,
      missingRows: missingRows,
      duplicatedRows: duplicatedRows,
      registrationErrors: registrationErrors,
      seamEnergies: seamEnergies,
      recoveredOrder: recoveredOrder?.map(\.rawValue),
      deterministic: deterministic,
      milliseconds: milliseconds
    )
  }

  // MARK: - Metrics

  /// The bundle's captures in the order the plan placed them, or nil when the
  /// plan names a capture the bundle does not have (a defect, never silently
  /// tolerated).
  static func capturesInPlanOrder(
    bundle: FixtureControlBundle,
    plan: ReconstructionPlan
  ) -> [CaptureAsset]? {
    var byID: [CaptureID: CaptureAsset] = [:]
    for capture in bundle.captures {
      byID[capture.id] = capture
    }
    var placed: [CaptureAsset] = []
    placed.reserveCapacity(plan.placements.count)
    for placement in plan.placements {
      guard let capture = byID[placement.captureID] else {
        return nil
      }
      placed.append(capture)
    }
    return placed
  }

  /// Overlaps between neighbors in documentary order, from the ground-truth
  /// capture origins; the expectation for ordering cases, whose supplied-order
  /// `expectedOverlaps` are deliberately empty.
  static func documentOrderOverlaps(_ truth: FixtureGroundTruth) -> [Int] {
    var byID: [String: FixtureGroundTruth.Capture] = [:]
    for capture in truth.captures {
      byID[capture.id] = capture
    }
    let ordered = truth.expectedOrder.compactMap { byID[$0] }
    guard ordered.count == truth.expectedOrder.count else {
      return []
    }
    return zip(ordered, ordered.dropFirst()).map { preceding, following in
      preceding.sourceOrigin + preceding.height - following.sourceOrigin
    }
  }

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
