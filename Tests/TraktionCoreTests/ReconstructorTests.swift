import Foundation
import Testing
import TraktionDomain
import TraktionVision

@testable import TraktionCore

struct ReconstructorTests {
  @Test func exactTwoImageOverlapMatchesSourcePixels() throws {
    let source = canvas(width: 8, height: 20)
    let result = try reconstruct([crop(source, 0..<13), crop(source, 7..<20)])
    #expect(result.image == source)
    #expect(result.plan.joints.first?.overlapRows == 6)
    #expect(result.plan.joints.first?.confidence == .exact)
  }

  @Test func exactThreeImageSequenceMatchesSourcePixels() throws {
    let source = canvas(width: 9, height: 30)
    let result = try reconstruct([
      crop(source, 0..<14), crop(source, 10..<24), crop(source, 20..<30),
    ])
    #expect(result.image == source)
    #expect(result.plan.joints.map(\.overlapRows) == [4, 4])
  }

  @Test func nearExactOverlapIsAcceptedWithoutFeathering() throws {
    let source = canvas(width: 8, height: 20)
    let upper = crop(source, 0..<13)
    var lower = crop(source, 7..<20)
    lower.rgba[0] &+= 1
    let result = try reconstruct([upper, lower])
    #expect(result.plan.outputHeight == source.height)
    #expect(result.plan.joints.first?.confidence == .strong)
    #expect(result.plan.joints.first?.meanAbsoluteError ?? 2 < 1)
  }

  @Test func repeatedRowsFailSafelyAsAmbiguous() throws {
    let rowA = [UInt8](repeating: 25, count: 16)
    let rowB = [UInt8](repeating: 90, count: 16)
    let first = PixelImage(width: 4, height: 6, rgba: rowA + rowB + rowA + rowB + rowA + rowB)
    let second = PixelImage(
      width: 4, height: 6, rgba: rowA + rowB + rowA + rowB + [UInt8](repeating: 140, count: 32))
    #expect(
      throws: ReconstructionFailure.ambiguousOverlap(
        upperCaptureID: "capture-1", lowerCaptureID: "capture-2")
    ) { try reconstruct([first, second]) }
  }

  @Test func insufficientOverlapReturnsTypedFailure() throws {
    #expect(
      throws: ReconstructionFailure.insufficientOverlap(
        upperCaptureID: "capture-1", lowerCaptureID: "capture-2")
    ) {
      try reconstruct([solid(width: 4, height: 5, value: 1), solid(width: 4, height: 5, value: 10)])
    }
  }

  @Test func widthMismatchReturnsTypedFailure() throws {
    #expect(
      throws: ReconstructionFailure.incompatibleDimensions(
        expectedWidth: 4, actualWidth: 5, captureID: "capture-2")
    ) {
      try reconstruct([solid(width: 4, height: 5, value: 1), solid(width: 5, height: 5, value: 1)])
    }
  }

  @Test func duplicateCaptureReturnsTypedFailure() throws {
    let image = canvas(width: 4, height: 5)
    #expect(throws: ReconstructionFailure.duplicateCapture(captureID: "capture-2")) {
      try reconstruct([image, image])
    }
  }

  @Test func pngRoundTripPreservesDecodedPixels() throws {
    let expected = canvas(width: 7, height: 11)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: url) }
    try PNGCodec.encode(expected, to: url)
    #expect(try PNGCodec.decode(contentsOf: url) == expected)
  }

  private func reconstruct(_ images: [PixelImage]) throws -> ReconstructionOutput {
    try Reconstructor().reconstruct(
      images: images.enumerated().map { index, image in
        (
          CaptureAsset(
            id: "capture-\(index + 1)", source: URL(fileURLWithPath: "/capture-\(index + 1).png"),
            width: image.width, height: image.height), image
        )
      })
  }
  private func canvas(width: Int, height: Int) -> PixelImage {
    var bytes = [UInt8]()
    for y in 0..<height {
      for x in 0..<width {
        bytes += [
          UInt8((x * 19 + y * 37) % 251), UInt8((x * 13 + y * 23) % 253),
          UInt8((x * 5 + y * 41) % 255), 255,
        ]
      }
    }
    return PixelImage(width: width, height: height, rgba: bytes)
  }
  private func crop(_ image: PixelImage, _ rows: Range<Int>) -> PixelImage {
    PixelImage(width: image.width, height: rows.count, rgba: Array(image.rows(rows)))
  }
  private func solid(width: Int, height: Int, value: UInt8) -> PixelImage {
    PixelImage(
      width: width, height: height, rgba: [UInt8](repeating: value, count: width * height * 4))
  }
}
