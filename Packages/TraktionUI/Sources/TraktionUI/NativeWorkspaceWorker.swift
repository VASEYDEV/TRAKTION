import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision

/// Synchronous work, always invoked on the workspace's serial background queue.
public protocol NativeWorkspaceWorking: Sendable {
  func importCaptures(
    from urls: [URL],
    retainedRasterBytes: Int,
    isCancelled: @Sendable () -> Bool
  ) throws -> [CaptureAsset]

  func reconstruct(_ captures: [CaptureAsset]) throws -> ReconstructionResult
}

public struct NativeWorkspaceWorker: NativeWorkspaceWorking {
  private let importer: PNGImportService
  private let engine: ReconstructionEngine

  public init(limits: PNGImportLimits = PNGImportLimits()) {
    importer = PNGImportService(limits: limits)
    engine = ReconstructionEngine()
  }

  public func importCaptures(
    from urls: [URL],
    retainedRasterBytes: Int,
    isCancelled: @Sendable () -> Bool
  ) throws -> [CaptureAsset] {
    try importer.importCaptures(
      from: urls, retainedRasterBytes: retainedRasterBytes, isCancelled: isCancelled
    )
  }

  public func reconstruct(_ captures: [CaptureAsset]) throws -> ReconstructionResult {
    try engine.reconstruct(CaptureSequence(captures: captures), axis: .vertical)
  }
}

/// The engine has no cooperative cancellation. This token cancels importer
/// checkpoints and publication; the queue remains occupied until work returns.
final class NativeWorkspaceCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false

  var isCancelled: Bool {
    lock.withLock { cancelled }
  }

  func cancel() {
    lock.withLock { cancelled = true }
  }
}

enum NativeRasterPreview {
  static let maximumResultPixels = 1_048_576
  static let maximumResultDimension = 4_096
  static let thumbnailDimension = 224

  static func dimensions(
    _ image: RasterImage, maximumDimension: Int, maximumPixels: Int
  ) -> (width: Int, height: Int) {
    precondition(maximumDimension > 0 && maximumPixels > 0)
    let longest = max(image.width, image.height)
    let count = image.pixels.count / RasterImage.channelsPerPixel
    let dimensionScale = Double(longest) / Double(maximumDimension)
    let pixelScale = sqrt(Double(count) / Double(maximumPixels))
    let scale = max(1, Int(ceil(max(dimensionScale, pixelScale))))
    return (max(1, image.width / scale), max(1, image.height / scale))
  }

  /// Admission occurs before any thumbnail buffer is allocated. Counting even
  /// shared, full-size previews and their CGImage copies is conservative; this
  /// is an owned-raster budget,
  /// not a bound on framework allocations or process resident memory.
  static func admitThumbnails(
    _ assets: [CaptureAsset], retainedBytes: Int, maximumBytes: Int
  ) throws {
    var total = retainedBytes
    for asset in assets {
      let size = dimensions(
        asset.image, maximumDimension: thumbnailDimension,
        maximumPixels: thumbnailDimension * thumbnailDimension
      )
      for bytes in [asset.image.pixels.count, size.width * size.height * 8] {
        let (next, overflow) = total.addingReportingOverflow(bytes)
        guard !overflow, total >= 0, next <= maximumBytes else {
          throw PNGImportFailure.resourceLimitExceeded(
            "The imported captures and their previews exceed the workspace raster budget."
          )
        }
        total = next
      }
    }
  }

  /// A display-only sample. The original captures and reconstructed raster
  /// remain unchanged and are never replaced by these preview pixels.
  static func make(
    _ image: RasterImage,
    maximumDimension: Int,
    maximumPixels: Int,
    isCancelled: @Sendable () -> Bool
  ) throws -> RasterImage {
    guard !isCancelled() else { throw PNGImportFailure.cancelled }
    let (width, height) = dimensions(
      image, maximumDimension: maximumDimension, maximumPixels: maximumPixels
    )
    if width == image.width && height == image.height { return image }

    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
      guard !isCancelled() else { throw PNGImportFailure.cancelled }
      let sourceY = y * image.height / height
      for x in 0..<width {
        let sourceX = x * image.width / width
        let source = image.byteOffset(x: sourceX, y: sourceY)
        let destination = (y * width + x) * 4
        pixels[destination] = image.pixels[source]
        pixels[destination + 1] = image.pixels[source + 1]
        pixels[destination + 2] = image.pixels[source + 2]
        pixels[destination + 3] = image.pixels[source + 3]
      }
    }
    return try RasterImage(width: width, height: height, pixels: pixels)
  }
}
