import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision

/// Bootstrap-scope fixture generation: one deterministic vertical sequence
/// with uniform overlap. The full control set (duplicates, reversed order,
/// missing coverage, sticky chrome, degradation) is tracked by
/// prompts/02_FIXTURE_FORGE.md and must extend this configuration rather than
/// fork it.
public struct FixtureConfiguration: Equatable, Sendable {
    public var sourceID: String
    public var width: Int
    public var viewportHeight: Int
    public var captureCount: Int
    public var overlap: Int
    public var seed: UInt64

    public init(
        sourceID: String = "fixture",
        width: Int = 96,
        viewportHeight: Int = 64,
        captureCount: Int = 3,
        overlap: Int = 16,
        seed: UInt64 = 1
    ) {
        self.sourceID = sourceID
        self.width = width
        self.viewportHeight = viewportHeight
        self.captureCount = captureCount
        self.overlap = overlap
        self.seed = seed
    }

    public var sourceHeight: Int {
        captureCount * viewportHeight - (captureCount - 1) * overlap
    }
}

public struct GeneratedFixture: Sendable {
    public let configuration: FixtureConfiguration
    public let source: PixelBuffer
    public let sourcePNG: [UInt8]
    /// Capture PNG bytes in expected order, parallel to `manifest.captures`.
    public let capturePNGs: [[UInt8]]
    public let manifest: FixtureManifest
}

public enum FixtureGeneratorError: Error, Equatable, Sendable {
    case invalidConfiguration(details: String)
    case ioFailure(details: String)
}

public enum FixtureGenerator {
    public static func generate(_ config: FixtureConfiguration) throws -> GeneratedFixture {
        guard config.captureCount >= 2 else {
            throw FixtureGeneratorError.invalidConfiguration(details: "captureCount must be >= 2")
        }
        guard config.overlap >= 1, config.overlap < config.viewportHeight else {
            throw FixtureGeneratorError.invalidConfiguration(
                details: "overlap must be in 1..<viewportHeight (\(config.overlap) vs \(config.viewportHeight))"
            )
        }
        guard config.width >= 8, config.viewportHeight >= 2 else {
            throw FixtureGeneratorError.invalidConfiguration(details: "canvas too small")
        }

        let source = CanvasRenderer.render(
            width: config.width,
            height: config.sourceHeight,
            seed: config.seed
        )
        let sourcePNG = PNGCodec.encode(source)

        var capturePNGs: [[UInt8]] = []
        var captureRecords: [FixtureManifest.Capture] = []
        var overlaps: [Int] = []
        for index in 0..<config.captureCount {
            let originY = index * (config.viewportHeight - config.overlap)
            let slice = source.verticalSlice(yOrigin: originY, rowCount: config.viewportHeight)
            let png = PNGCodec.encode(slice)
            let fileName = String(format: "capture-%03d.png", index + 1)
            capturePNGs.append(png)
            captureRecords.append(
                FixtureManifest.Capture(
                    id: String(format: "capture-%03d", index + 1),
                    fileName: fileName,
                    originY: originY,
                    pixelWidth: slice.width,
                    pixelHeight: slice.height,
                    expectedOrderIndex: index,
                    sha256: SHA256.hexDigest(png)
                )
            )
            if index > 0 {
                overlaps.append(config.overlap)
            }
        }

        let manifest = FixtureManifest(
            sourceID: config.sourceID,
            axis: .vertical,
            seed: config.seed,
            sourceWidth: source.width,
            sourceHeight: source.height,
            sourceFileName: "source.png",
            sourceSHA256: SHA256.hexDigest(sourcePNG),
            captures: captureRecords,
            expectedOverlaps: overlaps,
            expectedStatus: "reconstructable"
        )

        return GeneratedFixture(
            configuration: config,
            source: source,
            sourcePNG: sourcePNG,
            capturePNGs: capturePNGs,
            manifest: manifest
        )
    }

    /// Writes source.png, capture PNGs, and fixture.json into `directory`
    /// (created if needed). Returns the manifest path. Output is deterministic:
    /// identical configuration produces identical bytes.
    @discardableResult
    public static func write(_ fixture: GeneratedFixture, to directory: URL) throws -> URL {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(fixture.sourcePNG).write(to: directory.appendingPathComponent(fixture.manifest.sourceFileName))
            for (index, png) in fixture.capturePNGs.enumerated() {
                let fileName = fixture.manifest.captures[index].fileName
                try Data(png).write(to: directory.appendingPathComponent(fileName))
            }
            let manifestURL = directory.appendingPathComponent("fixture.json")
            try DeterministicJSON.encode(fixture.manifest).write(to: manifestURL)
            return manifestURL
        } catch let error as CocoaError {
            throw FixtureGeneratorError.ioFailure(details: error.localizedDescription)
        }
    }
}
