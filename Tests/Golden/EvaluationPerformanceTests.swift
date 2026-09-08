import FixtureForgeKit
import Foundation
import TraktionCore
import TraktionDomain
import XCTest

@testable import TraktionLabEvaluation

final class EvaluationPerformanceTests: XCTestCase {
  func testDifferentMeasurementsDoNotMakeIdenticalReconstructionsNondeterministic() throws {
    let bundle = try FixtureControlGenerator.generate(FixtureControlConfiguration())
    let result = try ReconstructionEngine().reconstruct(CaptureSequence(captures: bundle.captures))
    let first = EvaluationPerformanceMetrics.record(
      inputBytes: 400, elapsed: .seconds(1), sample: { 1000 }
    )
    let second = EvaluationPerformanceMetrics.record(
      inputBytes: 400, elapsed: .seconds(2), sample: { 2000 }
    )
    let assessment = try EvaluationHarness.assessRuns(
      name: "diagnostics-only", bundle: bundle, captures: bundle.captures,
      first: .init(
        outcome: .reconstructed(result), recoveredOrder: nil, milliseconds: 1000,
        performance: first
      ),
      second: .init(
        outcome: .reconstructed(result), recoveredOrder: nil, milliseconds: 2000,
        performance: second
      ),
      artifacts: nil
    )
    XCTAssertTrue(assessment.deterministic)
    XCTAssertEqual(assessment.verdict, .pass)
    XCTAssertEqual(assessment.performance, first)
  }

  func testPhoneAndLongCorpusGeometryAndInputDenominators() {
    let cases = EvaluationHarness.performanceCorpus()
    XCTAssertEqual(cases.map(\.name), ["performance-phone-3", "performance-long-10"])
    XCTAssertEqual(cases.map { $0.configuration.captureCount }, [3, 10])
    XCTAssertEqual(cases.map { $0.configuration.sourceLength }, [6196, 19020])
    for evaluationCase in cases {
      XCTAssertTrue(evaluationCase.measuresPerformance)
      XCTAssertEqual(evaluationCase.configuration.crossAxisSize, 1170)
      XCTAssertEqual(evaluationCase.configuration.viewportLength, 2532)
      XCTAssertEqual(evaluationCase.configuration.overlapLength, 700)
    }
  }

  func testPreciseThroughputAndPeakRatioUseRawInputPixels() throws {
    let metrics = EvaluationPerformanceMetrics.record(
      inputBytes: 400, elapsed: .microseconds(100), sample: { 4096 }
    )
    XCTAssertEqual(metrics.inputPixelCount, 100)
    XCTAssertEqual(metrics.peakResidentBytes, 4096)
    XCTAssertEqual(try XCTUnwrap(metrics.inputAmplification), 10.24, accuracy: 0.00001)
    XCTAssertEqual(try XCTUnwrap(metrics.inputPixelsPerSecond), 1_000_000, accuracy: 0.00001)
    XCTAssertEqual(metrics.reconstructionSeconds, 0.0001, accuracy: 0.0000001)
    XCTAssertEqual(metrics.memoryScope, "process-lifetime-high-water-after-reconstruction")
    XCTAssertNil(metrics.memorySamplingError)
    let decoded = try JSONDecoder().decode(
      EvaluationPerformanceMetrics.self, from: JSONEncoder().encode(metrics)
    )
    XCTAssertEqual(decoded, metrics)
  }

  func testFailedSamplingIsExplicitAndDoesNotDiscardThroughput() throws {
    enum SamplingFailure: Error { case unavailable }
    let metrics = EvaluationPerformanceMetrics.record(
      inputBytes: 400, elapsed: .seconds(2), sample: { throw SamplingFailure.unavailable }
    )
    XCTAssertNil(metrics.peakResidentBytes)
    XCTAssertNil(metrics.inputAmplification)
    XCTAssertNotNil(metrics.memorySamplingError)
    XCTAssertEqual(metrics.inputPixelsPerSecond, 50)
    XCTAssertNoThrow(try JSONEncoder().encode(metrics))
  }

  func testZeroTimeAndEmptyInputsNeverProduceInfiniteRatios() throws {
    let metrics = EvaluationPerformanceMetrics.record(
      inputBytes: 0, elapsed: .zero, sample: { 1 }
    )
    XCTAssertNil(metrics.inputPixelsPerSecond)
    XCTAssertNil(metrics.inputAmplification)
    XCTAssertEqual(metrics.peakResidentBytes, 1)
    XCTAssertNoThrow(try JSONEncoder().encode(metrics))
    let zeroSample = EvaluationPerformanceMetrics.record(
      inputBytes: 400, elapsed: .seconds(1), sample: { 0 }
    )
    XCTAssertNil(zeroSample.peakResidentBytes)
    XCTAssertNotNil(zeroSample.memorySamplingError)
  }

  func testHarnessRecordsOnlyOptedInCasesUsingActualInputBytes() throws {
    let report = try EvaluationHarness.evaluate([
      EvaluationCase(name: "ordinary", configuration: FixtureControlConfiguration()),
      EvaluationCase(
        name: "measured", configuration: FixtureControlConfiguration(), measuresPerformance: true
      ),
    ])
    XCTAssertTrue(report.summary.isAcceptable)
    XCTAssertNil(report.cases[0].performance)
    let metrics = try XCTUnwrap(report.cases[1].performance)
    XCTAssertEqual(metrics.inputBytes, 64 * 96 * 3 * 4)
    XCTAssertEqual(metrics.inputPixelCount, 64 * 96 * 3)
    XCTAssertGreaterThan(try XCTUnwrap(metrics.peakResidentBytes), 0)
    XCTAssertEqual(
      try JSONDecoder().decode(EvaluationReport.self, from: JSONEncoder().encode(report)), report
    )
  }

  func testAdvisoryBoundaryAndValidationNeverMutateTheGate() throws {
    for value in ["0", "-1", "nan", "NaN", "inf", "-inf", "1e999", "", "no"] {
      XCTAssertThrowsError(try EvaluationMemoryAdvisory(value), value)
    }
    var report = try EvaluationHarness.evaluate([
      EvaluationCase(name: "measured", configuration: FixtureControlConfiguration())
    ])
    report.cases[0].performance = EvaluationPerformanceMetrics.record(
      inputBytes: 1000, elapsed: .seconds(1), sample: { 2000 }
    )
    let original = report
    XCTAssertTrue(try EvaluationMemoryAdvisory("2").warnings(in: report).isEmpty)
    XCTAssertEqual(try EvaluationMemoryAdvisory("1.99").warnings(in: report).count, 1)
    XCTAssertEqual(report, original)
    XCTAssertTrue(report.summary.isAcceptable)

    var failed = try EvaluationHarness.evaluate([
      EvaluationCase(
        name: "invalid-axis", configuration: FixtureControlConfiguration(), engineAxis: .horizontal
      )
    ])
    failed.cases[0].performance = report.cases[0].performance
    let failedOriginal = failed
    XCTAssertEqual(try EvaluationMemoryAdvisory("1").warnings(in: failed).count, 1)
    XCTAssertFalse(failed.summary.isAcceptable)
    XCTAssertEqual(failed, failedOriginal)
  }
}
