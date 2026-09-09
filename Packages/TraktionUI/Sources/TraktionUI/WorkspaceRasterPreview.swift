#if canImport(SwiftUI)
  import CoreGraphics
  import Foundation
  import SwiftUI
  import TraktionDomain

  /// Receives only worker-generated bounded previews, never source/full-result rasters.
  @MainActor
  struct WorkspaceRasterPreview: View {
    let raster: RasterImage
    let label: String
    @State private var image: CGImage?

    var body: some View {
      Group {
        if let image {
          Image(image, scale: 1, orientation: .up, label: Text(label))
            .resizable()
            .interpolation(.none)
            .scaledToFit()
        } else {
          Text("Preview unavailable")
            .font(.caption)
        }
      }
      .onChange(of: raster, initial: true) { _, raster in
        image = Self.makeImage(raster)
      }
    }

    private static func makeImage(_ raster: RasterImage) -> CGImage? {
      // Guard the rendering boundary even if a caller supplies an unbounded raster.
      guard raster.width <= 4096, raster.height <= 4096,
        raster.pixels.count <= 4_194_304,
        let provider = CGDataProvider(data: Data(raster.pixels) as CFData)
      else { return nil }
      return CGImage(
        width: raster.width,
        height: raster.height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: raster.rowByteCount,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
          .union(.byteOrder32Big),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    }
  }
#endif
