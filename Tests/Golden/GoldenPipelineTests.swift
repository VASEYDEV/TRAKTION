import Foundation
import Testing
import FixtureForgeKit
import TraktionCore
import TraktionDomain
import TraktionLabKit
import TraktionVision

/// End-to-end proof that the harness can generate deterministic fixtures, load
/// source assets through the shipping ingest path, and write diagnostics —
/// covering the failure paths as thoroughly as the success path.
@Suite("Golden pipeline")
struct GoldenPipelineTests {
    private func makeTempDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("traktion-golden-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeFixture(
        _ config: FixtureConfiguration, into directory: URL
    ) throws -> (fixture: GeneratedFixture, capturePaths: [String]) {
        let fixture = try FixtureGenerator.generate(config)
        try FixtureGenerator.write(fixture, to: directory)
        let paths = fixture.manifest.captures.map { directory.appendingPathComponent($0.fileName).path }
        return (fixture, paths)
    }

    @Test("Generate → ingest → manifest, deterministically")
    func endToEndIngest() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let config = FixtureConfiguration(sourceID: "golden-e2e", seed: 99)
        let (fixture, capturePaths) = try writeFixture(config, into: directory)

        let outputBase = directory.appendingPathComponent("run/e2e").path
        let outcome = try LabIngest.run(inputPaths: capturePaths, axis: .vertical, outputBase: outputBase)

        #expect(outcome.manifest.status == .ingested)
        #expect(outcome.manifest.failure == nil)
        #expect(outcome.manifest.captures.count == config.captureCount)
        #expect(outcome.buffers.count == config.captureCount)

        for (index, capture) in outcome.manifest.captures.enumerated() {
            let truth = fixture.manifest.captures[index]
            #expect(capture.fileName == truth.fileName)
            #expect(capture.pixelWidth == truth.pixelWidth)
            #expect(capture.pixelHeight == truth.pixelHeight)
            #expect(capture.sha256 == truth.sha256, "ingest must see the exact bytes FixtureForge wrote")
        }

        // The manifest sidecar exists, decodes, and matches the in-memory result.
        let manifestData = try Data(contentsOf: URL(fileURLWithPath: outcome.manifestPath))
        let decoded = try DeterministicJSON.decode(ReconstructionManifest.self, from: manifestData)
        #expect(decoded == outcome.manifest)

        // A second identical run produces a byte-identical manifest.
        let secondBase = directory.appendingPathComponent("run/e2e-repeat").path
        let second = try LabIngest.run(inputPaths: capturePaths, axis: .vertical, outputBase: secondBase)
        let secondData = try Data(contentsOf: URL(fileURLWithPath: second.manifestPath))
        #expect(manifestData == secondData)
    }

    @Test("Committed baseline fixture regenerates byte-identically and ingests")
    func committedBaseline() throws {
        let baselineDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // Tests/Golden
            .deletingLastPathComponent()          // Tests
            .appendingPathComponent("SyntheticFixtures/baseline-vertical-3")

        let manifestData = try Data(contentsOf: baselineDirectory.appendingPathComponent("fixture.json"))
        let truth = try DeterministicJSON.decode(FixtureManifest.self, from: manifestData)

        // Reconstruct the generating configuration from the committed ground truth.
        let config = FixtureConfiguration(
            sourceID: truth.sourceID,
            width: truth.sourceWidth,
            viewportHeight: truth.captures[0].pixelHeight,
            captureCount: truth.captures.count,
            overlap: truth.expectedOverlaps[0],
            seed: truth.seed
        )
        let regenerated = try FixtureGenerator.generate(config)

        // Byte-identical regeneration locks cross-platform determinism.
        #expect(regenerated.manifest == truth)
        #expect(try DeterministicJSON.encode(regenerated.manifest) == manifestData)
        let committedSource = try Data(contentsOf: baselineDirectory.appendingPathComponent(truth.sourceFileName))
        #expect(Data(regenerated.sourcePNG) == committedSource)
        for capture in truth.captures {
            let committed = try Data(contentsOf: baselineDirectory.appendingPathComponent(capture.fileName))
            #expect(SHA256.hexDigest([UInt8](committed)) == capture.sha256)
        }

        // The committed captures ingest cleanly through the shipping path.
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let paths = truth.captures.map { baselineDirectory.appendingPathComponent($0.fileName).path }
        let outcome = try LabIngest.run(
            inputPaths: paths,
            axis: .vertical,
            outputBase: directory.appendingPathComponent("baseline").path
        )
        #expect(outcome.manifest.status == .ingested)
    }

    @Test("Width mismatch fails typed, and still writes the manifest")
    func widthMismatchFails() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let narrow = try writeFixture(
            FixtureConfiguration(sourceID: "narrow", width: 64, seed: 1),
            into: directory.appendingPathComponent("narrow")
        )
        let wide = try writeFixture(
            FixtureConfiguration(sourceID: "wide", width: 96, seed: 2),
            into: directory.appendingPathComponent("wide")
        )

        let outcome = try LabIngest.run(
            inputPaths: [narrow.capturePaths[0], wide.capturePaths[0]],
            axis: .vertical,
            outputBase: directory.appendingPathComponent("mixed").path
        )
        #expect(outcome.manifest.status == .failed)
        #expect(outcome.buffers.isEmpty)
        guard case .incompatibleDimensions(_, let expected, let found)? = outcome.manifest.failure else {
            Issue.record("expected incompatibleDimensions, got \(String(describing: outcome.manifest.failure))")
            return
        }
        #expect(expected == 64)
        #expect(found == 96)
        #expect(FileManager.default.fileExists(atPath: outcome.manifestPath))
    }

    @Test("Capture-count and axis violations fail typed")
    func policyViolationsFail() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (_, capturePaths) = try writeFixture(FixtureConfiguration(sourceID: "policy", seed: 3), into: directory)

        let single = try LabIngest.run(
            inputPaths: [capturePaths[0]],
            axis: .vertical,
            outputBase: directory.appendingPathComponent("single").path
        )
        #expect(single.manifest.failure == .invalidCaptureCount(found: 1, minimum: 2, maximum: 10))

        let horizontal = try LabIngest.run(
            inputPaths: capturePaths,
            axis: .horizontal,
            outputBase: directory.appendingPathComponent("horizontal").path
        )
        guard case .unsupportedTransform? = horizontal.manifest.failure else {
            Issue.record("expected unsupportedTransform, got \(String(describing: horizontal.manifest.failure))")
            return
        }
    }

    @Test("Unreadable and corrupt assets fail typed, naming the file")
    func unreadableAssetsFail() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (_, capturePaths) = try writeFixture(FixtureConfiguration(sourceID: "corrupt", seed: 4), into: directory)

        let missing = try LabIngest.run(
            inputPaths: [capturePaths[0], directory.appendingPathComponent("does-not-exist.png").path],
            axis: .vertical,
            outputBase: directory.appendingPathComponent("missing").path
        )
        #expect(missing.manifest.failure
            == .unreadableAsset(fileName: "does-not-exist.png", reason: "file could not be read"))

        let corruptPath = directory.appendingPathComponent("corrupt.png")
        try Data([1, 2, 3, 4, 5, 6, 7, 8, 9]).write(to: corruptPath)
        let corrupt = try LabIngest.run(
            inputPaths: [capturePaths[0], corruptPath.path],
            axis: .vertical,
            outputBase: directory.appendingPathComponent("corrupt-run").path
        )
        guard case .unreadableAsset(let fileName, _)? = corrupt.manifest.failure else {
            Issue.record("expected unreadableAsset, got \(String(describing: corrupt.manifest.failure))")
            return
        }
        #expect(fileName == "corrupt.png")
    }
}
