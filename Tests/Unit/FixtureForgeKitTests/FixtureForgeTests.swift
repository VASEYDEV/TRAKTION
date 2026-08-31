import Foundation
import Testing
import FixtureForgeKit
import TraktionDomain
import TraktionVision

@Suite("FixtureForge determinism and ground truth")
struct FixtureForgeTests {
    private let config = FixtureConfiguration(
        sourceID: "unit", width: 64, viewportHeight: 40, captureCount: 3, overlap: 10, seed: 7
    )

    @Test("Identical configuration produces byte-identical output")
    func determinism() throws {
        let first = try FixtureGenerator.generate(config)
        let second = try FixtureGenerator.generate(config)
        #expect(first.sourcePNG == second.sourcePNG)
        #expect(first.capturePNGs == second.capturePNGs)
        #expect(first.manifest == second.manifest)
        #expect(try DeterministicJSON.encode(first.manifest) == DeterministicJSON.encode(second.manifest))
    }

    @Test("Different seeds produce different canvases")
    func seedSensitivity() throws {
        var other = config
        other.seed = 8
        #expect(try FixtureGenerator.generate(config).sourcePNG != FixtureGenerator.generate(other).sourcePNG)
    }

    @Test("Captures are exact slices of the source at their recorded origins")
    func slicesMatchGroundTruth() throws {
        let fixture = try FixtureGenerator.generate(config)
        #expect(fixture.source.height == config.sourceHeight)
        for (index, record) in fixture.manifest.captures.enumerated() {
            let decoded = try PNGCodec.decode(fixture.capturePNGs[index])
            let expected = fixture.source.verticalSlice(yOrigin: record.originY, rowCount: record.pixelHeight)
            #expect(decoded == expected, "capture \(record.id) must equal source rows \(record.originY)..<\(record.originY + record.pixelHeight)")
        }
    }

    @Test("Consecutive captures share exactly the expected overlap rows")
    func overlapRowsMatch() throws {
        let fixture = try FixtureGenerator.generate(config)
        let buffers = try fixture.capturePNGs.map { try PNGCodec.decode($0) }
        for joint in 0..<(buffers.count - 1) {
            let overlap = fixture.manifest.expectedOverlaps[joint]
            let upper = buffers[joint]
            let lower = buffers[joint + 1]
            let upperTail = upper.verticalSlice(yOrigin: upper.height - overlap, rowCount: overlap)
            let lowerHead = lower.verticalSlice(yOrigin: 0, rowCount: overlap)
            #expect(upperTail.pixels == lowerHead.pixels, "joint \(joint) overlap must be pixel-identical")
        }
    }

    @Test("Every source row is unique, so overlap detection cannot alias")
    func rowsAreUnique() throws {
        let fixture = try FixtureGenerator.generate(config)
        var seen = Set<[UInt8]>()
        for y in 0..<fixture.source.height {
            let row = Array(fixture.source.row(y))
            #expect(!seen.contains(row), "row \(y) duplicates an earlier row")
            seen.insert(row)
        }
    }

    @Test("Invalid configurations are rejected with typed errors")
    func invalidConfiguration() {
        var tooFew = config
        tooFew.captureCount = 1
        #expect(throws: FixtureGeneratorError.self) { _ = try FixtureGenerator.generate(tooFew) }

        var badOverlap = config
        badOverlap.overlap = config.viewportHeight
        #expect(throws: FixtureGeneratorError.self) { _ = try FixtureGenerator.generate(badOverlap) }
    }
}
