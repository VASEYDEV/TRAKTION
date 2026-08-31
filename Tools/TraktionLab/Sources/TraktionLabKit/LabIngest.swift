import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision

/// Ingest stage of the lab pipeline: load capture files in supplied order,
/// decode, record identity metadata, validate against Milestone 1 constraints,
/// and write the machine-readable manifest sidecar.
///
/// Diagnostics are written on failure as well as success — a failed run leaves
/// a `failed` manifest with the typed failure, never nothing.
public struct IngestOutcome: Sendable {
    public let manifest: ReconstructionManifest
    public let manifestPath: String
    /// Decoded working rasters in sequence order (empty when ingest failed
    /// before decode completed). Derived data only; source files are untouched.
    public let buffers: [PixelBuffer]
}

public enum LabIngest {
    public static let generatorName = "traktion-lab 0.1.0"

    /// Runs ingest and writes `<outputBase>.reconstruction.json`.
    public static func run(
        inputPaths: [String],
        axis: ReconstructionAxis,
        outputBase: String
    ) throws -> IngestOutcome {
        var captures: [CaptureAsset] = []
        var buffers: [PixelBuffer] = []
        var failure: ReconstructionFailure?

        for (index, path) in inputPaths.enumerated() {
            let fileName = (path as NSString).lastPathComponent
            let bytes: [UInt8]
            do {
                bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: path)))
            } catch {
                failure = .unreadableAsset(fileName: fileName, reason: "file could not be read")
                break
            }
            let buffer: PixelBuffer
            do {
                buffer = try PNGCodec.decode(bytes)
            } catch let pngError as PNGError {
                failure = .unreadableAsset(fileName: fileName, reason: "PNG decode failed: \(pngError)")
                break
            }
            captures.append(
                CaptureAsset(
                    id: String(format: "capture-%03d", index + 1),
                    fileName: fileName,
                    pixelWidth: buffer.width,
                    pixelHeight: buffer.height,
                    byteCount: bytes.count,
                    sha256: SHA256.hexDigest(bytes)
                )
            )
            buffers.append(buffer)
        }

        if failure == nil {
            let sequence = CaptureSequence(axis: axis, captures: captures)
            failure = SequenceValidator.validate(sequence)
        }

        let manifest = ReconstructionManifest(
            generator: generatorName,
            axis: axis,
            status: failure == nil ? .ingested : .failed,
            captures: captures,
            failure: failure
        )

        let manifestPath = outputBase + ".reconstruction.json"
        let manifestURL = URL(fileURLWithPath: manifestPath)
        let parent = manifestURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try DeterministicJSON.encode(manifest).write(to: manifestURL)

        return IngestOutcome(
            manifest: manifest,
            manifestPath: manifestPath,
            buffers: failure == nil ? buffers : []
        )
    }
}
