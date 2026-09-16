import Foundation
import TraktionDomain
#if canImport(CoreGraphics)
  import CoreGraphics
#endif

enum InspectionFailure: Error, Equatable {
  case invalidViewport
  case invalidJoint
  case resourceLimit
  case cancelled
  case displayUnavailable
}

/// Coordinates are source pixels; zoom is display pixels per source pixel.
/// No full-resolution display image is constructed, even at Fit or 1:1.
struct InspectionViewport: Equatable, Sendable {
  static let maximumEdge = 1_024
  static let maximumBytes = maximumEdge * maximumEdge * 4
  // Published raster + CGData, next raster + CGData, and two transient copies.
  // This is owned raster/display storage, not a process RSS or GPU limit.
  static let reservedBytes = maximumBytes * 6

  let width: Int
  let height: Int
  let x: Double
  let y: Double
  let zoom: Double

  init(width: Int, height: Int, x: Double, y: Double, zoom: Double) throws {
    guard (1...Self.maximumEdge).contains(width),
      (1...Self.maximumEdge).contains(height), x.isFinite, y.isFinite,
      x >= 0, y >= 0, zoom.isFinite, (1.0 / 65_536...16).contains(zoom)
    else { throw InspectionFailure.invalidViewport }
    self.width = width
    self.height = height
    self.x = x
    self.y = y
    self.zoom = zoom
  }
}

struct InspectionFrame: Sendable {
  let viewport: InspectionViewport
  let raster: RasterImage
  #if canImport(CoreGraphics)
    let image: CGImage
  #endif

  init(viewport: InspectionViewport, raster: RasterImage) throws {
    self.viewport = viewport
    self.raster = raster
    #if canImport(CoreGraphics)
      guard let provider = CGDataProvider(data: Data(raster.pixels) as CFData),
        let image = CGImage(
          width: raster.width, height: raster.height, bitsPerComponent: 8,
          bitsPerPixel: 32, bytesPerRow: raster.rowByteCount,
          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            .union(.byteOrder32Big),
          provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
      else { throw InspectionFailure.displayUnavailable }
      self.image = image
    #endif
  }
}

protocol InspectionRendering: Sendable {
  func render(
    _ source: RasterImage, viewport: InspectionViewport,
    isCancelled: @Sendable () -> Bool
  ) throws -> InspectionFrame
}

struct InspectionRasterRenderer: InspectionRendering {
  func render(
    _ source: RasterImage, viewport: InspectionViewport,
    isCancelled: @Sendable () -> Bool
  ) throws -> InspectionFrame {
    guard viewport.x < Double(source.width), viewport.y < Double(source.height)
    else { throw InspectionFailure.invalidViewport }
    guard !isCancelled() else { throw InspectionFailure.cancelled }
    var pixels = [UInt8](repeating: 0, count: viewport.width * viewport.height * 4)
    for y in 0..<viewport.height {
      guard !isCancelled() else { throw InspectionFailure.cancelled }
      let sy = viewport.y + Double(y) / viewport.zoom
      guard sy < Double(source.height) else { continue }
      let sourceY = Int(sy.rounded(.down))
      for x in 0..<viewport.width {
        let sx = viewport.x + Double(x) / viewport.zoom
        guard sx < Double(source.width) else { continue }
        let sourceOffset = (sourceY * source.width + Int(sx.rounded(.down))) * 4
        let destination = (y * viewport.width + x) * 4
        for channel in 0..<4 { pixels[destination + channel] = source.pixels[sourceOffset + channel] }
      }
    }
    guard !isCancelled() else { throw InspectionFailure.cancelled }
    return try InspectionFrame(
      viewport: viewport,
      raster: RasterImage(width: viewport.width, height: viewport.height, pixels: pixels)
    )
  }
}

/// Resolve through stable IDs, never the current array index or basename.
/// Seam rows are boundaries: the following capture owns outputSeamRow onward.
struct InspectionJoint: Sendable {
  let diagnosis: JointDiagnosis
  let preceding: CaptureAsset
  let following: CaptureAsset
  let precedingOrigin: Int
  let followingOrigin: Int

  init(_ diagnosis: JointDiagnosis, result: ReconstructionResult, captures: [CaptureAsset]) throws {
    guard let preceding = captures.first(where: { $0.id == diagnosis.precedingCaptureID }),
      let following = captures.first(where: { $0.id == diagnosis.followingCaptureID }),
      let first = result.plan.placements.first(where: { $0.captureID == preceding.id }),
      let second = result.plan.placements.first(where: { $0.captureID == following.id }),
      diagnosis.overlapRows > 0,
      diagnosis.overlapRows <= min(preceding.image.height, following.image.height),
      (0...diagnosis.overlapRows).contains(diagnosis.seamRowInOverlap),
      first.originY >= 0, second.originY >= first.originY,
      second.originY < result.image.height,
      diagnosis.outputSeamRow >= second.originY,
      diagnosis.outputSeamRow < result.image.height,
      diagnosis.outputSeamRow - second.originY == diagnosis.seamRowInOverlap,
      second.originY - first.originY == preceding.image.height - diagnosis.overlapRows
    else { throw InspectionFailure.invalidJoint }
    self.diagnosis = diagnosis
    self.preceding = preceding
    self.following = following
    precedingOrigin = first.originY
    followingOrigin = second.originY
  }

  var precedingSeamRow: Int { diagnosis.outputSeamRow - precedingOrigin }
  var followingSeamRow: Int { diagnosis.seamRowInOverlap }
}
