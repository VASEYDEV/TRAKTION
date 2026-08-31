import Foundation
import Testing
import FixtureForgeKit
import TraktionLabKit
import TraktionVision

/// Coarse latency guardrails (docs/EVALUATION.md "Performance"). These bounds
/// are deliberately generous — they exist to catch pathological regressions
/// (accidental quadratic behavior), not to benchmark. Real performance
/// tracking needs dedicated fixtures and a quiet machine.
@Suite("Performance smoke")
struct PerformanceSmokeTests {
    @Test("Moderate fixture generates, encodes, and ingests within a generous bound")
    func moderateFixtureLatency() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("traktion-perf-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let config = FixtureConfiguration(
            sourceID: "perf", width: 320, viewportHeight: 512, captureCount: 6, overlap: 64, seed: 11
        )

        let clock = ContinuousClock()
        let start = clock.now

        let fixture = try FixtureGenerator.generate(config)
        try FixtureGenerator.write(fixture, to: directory)
        let paths = fixture.manifest.captures.map { directory.appendingPathComponent($0.fileName).path }
        let outcome = try LabIngest.run(
            inputPaths: paths,
            axis: .vertical,
            outputBase: directory.appendingPathComponent("perf").path
        )

        let elapsed = clock.now - start
        #expect(outcome.manifest.status == .ingested)
        #expect(elapsed < .seconds(60), "generate+write+ingest took \(elapsed); investigate a pathological regression")
        print("performance-smoke: \(config.captureCount) captures at \(config.width)x\(config.sourceHeight) in \(elapsed)")
    }
}
