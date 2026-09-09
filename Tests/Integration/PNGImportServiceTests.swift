import FixtureForgeKit
import Foundation
import TraktionDomain
@testable import TraktionVision
import XCTest

final class PNGImportServiceTests: XCTestCase {
  func testRealPNGImportPreservesPixelsSuppliedOrderAndOriginalBytes() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let urls = try files.write(fixture.captures.map(\.image))
    let originals = try urls.map { try Data(contentsOf: $0) }
    let seen = ImportCounter()
    let service = PNGImportService(stagingParent: files.staging) { url in
      // Both independent snapshots must exist before the first raster allocation.
      let batch = url.deletingLastPathComponent().deletingLastPathComponent()
      XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: batch.path).count, 2)
      seen.increment()
      return try PNGCodec.decodeOpaqueRGBA8(from: url)
    }

    let captures = try service.importCaptures(from: urls.reversed())

    XCTAssertEqual(captures.map(\.image), fixture.captures.reversed().map(\.image))
    XCTAssertEqual(captures.map(\.sourceName), urls.reversed().map(\.lastPathComponent))
    XCTAssertEqual(Set(captures.map(\.id)).count, 2)
    XCTAssertEqual(seen.value, 2)
    XCTAssertEqual(try urls.map { try Data(contentsOf: $0) }, originals)
    try files.assertClean()
  }

  func testMetadataReadsRealHeaderAndEncodedSizeWithoutRasterDecode() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let image = try SyntheticFixtureFactory.document(width: 48, height: 96, seed: 14)
    let url = try files.write([image])[0]
    let metadata = try PNGMetadata.inspect(from: url)
    XCTAssertEqual(metadata.width, 48)
    XCTAssertEqual(metadata.height, 96)
    XCTAssertEqual(metadata.pixelCount, 48 * 96)
    XCTAssertEqual(metadata.encodedByteCount, try Data(contentsOf: url).count)
  }

  func testSameSourceSelectedTwiceGetsDistinctStableCaptureIDs() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let source = try SyntheticFixtureFactory.document(width: 8, height: 8, seed: 17)
    let url = try files.write([source])[0]
    let captures = try PNGImportService(stagingParent: files.staging).importCaptures(from: [url, url])
    XCTAssertEqual(captures[0].image, source)
    XCTAssertEqual(captures[1].image, source)
    XCTAssertNotEqual(captures[0].id, captures[1].id)
    let reordered = Array(captures.reversed())
    XCTAssertEqual(reordered[1].id, captures[0].id)
    try files.assertClean()
  }

  func testInvalidCountOrRemoteURLDoesNotCreateOwnedFiles() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let service = PNGImportService(stagingParent: files.staging)
    let url = files.root.appendingPathComponent("absent.png")
    for count in [0, 1, 11] {
      XCTAssertThrowsError(try service.importCaptures(from: Array(repeating: url, count: count))) {
        XCTAssertEqual($0 as? PNGImportFailure, .countOutOfRange(count))
      }
    }
    XCTAssertThrowsError(try service.importCaptures(from: [URL(string: "https://example.invalid/a.png")!, url])) {
      XCTAssertEqual($0 as? PNGImportFailure, .invalidFile("a.png"))
    }
    try files.assertClean()
  }

  func testDirectoryAndMissingFileFailWithoutTouchingSources() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let image = try SyntheticFixtureFactory.document(width: 8, height: 8, seed: 7)
    let good = try files.write([image])[0]
    let original = try Data(contentsOf: good)
    for invalid in [files.root, files.root.appendingPathComponent("absent.png")] {
      XCTAssertThrowsError(try PNGImportService(stagingParent: files.staging).importCaptures(from: [good, invalid])) {
        XCTAssertTrue($0 is PNGImportFailure)
      }
      XCTAssertEqual(try Data(contentsOf: good), original)
      try files.assertClean()
    }
  }

  func testNonPNGCorruptAndAnimatedInputsFailBeforeAnyDecode() throws {
    let image = try SyntheticFixtureFactory.document(width: 8, height: 8, seed: 7)
    let bytes = PurePNGCodec.encode(image)
    var corruptCRC = bytes
    corruptCRC[29] ^= 1
    let animated = Array(bytes.prefix(33)) + pngChunk("acTL", [0, 0, 0, 2, 0, 0, 0, 0]) + bytes.dropFirst(33)
    let lateAnimation = Array(bytes.dropLast(12)) + pngChunk("fdAT", [0, 0, 0, 0]) + bytes.suffix(12)
    let invalidInputs = [Array("not a PNG".utf8), corruptCRC, Array(bytes.dropLast()), animated, lateAnimation, bytes + [0]]
    for invalid in invalidInputs {
      let files = try ImportFiles()
      defer { files.remove() }
      let urls = try files.writeBytes([bytes, invalid])
      let count = ImportCounter()
      let service = PNGImportService(stagingParent: files.staging) { url in
        count.increment()
        return try PNGCodec.decodeOpaqueRGBA8(from: url)
      }
      XCTAssertThrowsError(try service.importCaptures(from: urls)) { error in
        guard case .codec = error as? PNGImportFailure else {
          return XCTFail("Expected a typed codec refusal; got \(error)")
        }
      }
      XCTAssertEqual(count.value, 0)
      XCTAssertEqual(try urls.map { Array(try Data(contentsOf: $0)) }, [bytes, invalid])
      try files.assertClean()
    }
  }

  func testOversizedHeaderFailsBeforeAnyDecode() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let image = try SyntheticFixtureFactory.document(width: 8, height: 8, seed: 7)
    let bytes = PurePNGCodec.encode(image)
    for dimensions: [UInt32] in [[0, 8], [4097, 4096], [UInt32.max, UInt32.max]] {
      let header = bigEndian(dimensions[0]) + bigEndian(dimensions[1]) + [8, 6, 0, 0, 0]
      let oversized = Array(bytes.prefix(8)) + pngChunk("IHDR", header) + bytes.dropFirst(33)
      let urls = try files.writeBytes([bytes, oversized], prefix: UUID().uuidString)
      let count = ImportCounter()
      XCTAssertThrowsError(try PNGImportService(stagingParent: files.staging, decode: { url in
        count.increment()
        return try PNGCodec.decodeOpaqueRGBA8(from: url)
      }).importCaptures(from: urls)) {
        XCTAssertEqual($0 as? PNGImportFailure, .codec(.resourceLimitExceeded(urls[1].lastPathComponent)))
      }
      XCTAssertEqual(count.value, 0)
      try files.assertClean()
    }
  }

  func testWidthAndAggregateLimitsAreCheckedBeforeDecode() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let image = try SyntheticFixtureFactory.document(width: 8, height: 8, seed: 7)
    let different = try SyntheticFixtureFactory.document(width: 9, height: 8, seed: 8)
    let mixed = try files.write([image, different])
    let count = ImportCounter()
    let decoder: @Sendable (URL) throws -> RasterImage = { url in
      count.increment()
      return try PNGCodec.decodeOpaqueRGBA8(from: url)
    }
    XCTAssertThrowsError(try PNGImportService(stagingParent: files.staging, decode: decoder).importCaptures(from: mixed)) {
      XCTAssertEqual($0 as? PNGImportFailure, .incompatibleWidth(name: mixed[1].lastPathComponent, expected: 8, actual: 9))
    }
    let same = [mixed[0], mixed[0]]
    for limits in [PNGImportLimits(maximumTotalInputPixels: 127), PNGImportLimits(maximumRetainedRasterBytes: 511)] {
      XCTAssertThrowsError(try PNGImportService(limits: limits, stagingParent: files.staging, decode: decoder).importCaptures(from: same)) {
        guard case .resourceLimitExceeded = $0 as? PNGImportFailure else { return XCTFail("Expected resource refusal") }
      }
    }
    XCTAssertEqual(count.value, 0)
    try files.assertClean()
  }

  func testRetainedWorkspaceBudgetAndOverflowAreCheckedBeforeDecode() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let image = try SyntheticFixtureFactory.document(width: 8, height: 8, seed: 7)
    let urls = try files.write([image, image])
    let count = ImportCounter()
    let service = PNGImportService(
      limits: PNGImportLimits(maximumRetainedRasterBytes: 1024), stagingParent: files.staging
    ) { url in
      count.increment()
      return try PNGCodec.decodeOpaqueRGBA8(from: url)
    }
    for retained in [513, Int.max, -1] {
      XCTAssertThrowsError(try service.importCaptures(from: urls, retainedRasterBytes: retained)) {
        guard case .resourceLimitExceeded = $0 as? PNGImportFailure else { return XCTFail("Expected resource refusal") }
      }
      XCTAssertEqual(count.value, 0)
      try files.assertClean()
    }
    XCTAssertEqual(try service.importCaptures(from: urls, retainedRasterBytes: 512).count, 2)
    try files.assertClean()
  }

  func testEncodedFileAndBatchAllowancesBoundOwnedCopies() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let image = try SyntheticFixtureFactory.document(width: 8, height: 8, seed: 7)
    let bytes = PurePNGCodec.encode(image)
    let urls = try files.writeBytes([bytes, bytes])
    for limits in [
      PNGImportLimits(maximumEncodedBytesPerFile: bytes.count - 1),
      PNGImportLimits(maximumTotalEncodedBytes: bytes.count * 2 - 1),
      PNGImportLimits(maximumEncodedBytesPerFile: 0),
    ] {
      let count = ImportCounter()
      XCTAssertThrowsError(try PNGImportService(limits: limits, stagingParent: files.staging, decode: { url in
        count.increment()
        return try PNGCodec.decodeOpaqueRGBA8(from: url)
      }).importCaptures(from: urls)) {
        guard case .resourceLimitExceeded = $0 as? PNGImportFailure else { return XCTFail("Expected resource refusal") }
      }
      XCTAssertEqual(count.value, 0)
      XCTAssertEqual(try urls.map { Array(try Data(contentsOf: $0)) }, [bytes, bytes])
      try files.assertClean()
    }
    let exact = PNGImportLimits(maximumEncodedBytesPerFile: bytes.count, maximumTotalEncodedBytes: bytes.count * 2)
    XCTAssertEqual(try PNGImportService(limits: exact, stagingParent: files.staging).importCaptures(from: urls).count, 2)
    try files.assertClean()
  }

  func testTransparencyFailureDoesNotReturnPartialBatch() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let opaque = try RasterImage(width: 2, height: 2, pixels: Array(repeating: 255, count: 16))
    var pixels = opaque.pixels
    pixels[3] = 64
    let transparent = try RasterImage(width: 2, height: 2, pixels: pixels)
    let bytes = [PurePNGCodec.encode(opaque), PurePNGCodec.encode(transparent)]
    let urls = try files.writeBytes(bytes)
    XCTAssertThrowsError(try PNGImportService(stagingParent: files.staging).importCaptures(from: urls)) {
      XCTAssertEqual($0 as? PNGImportFailure, .codec(.unsupportedTransparency(urls[1].lastPathComponent)))
    }
    XCTAssertEqual(try urls.map { Array(try Data(contentsOf: $0)) }, bytes)
    try files.assertClean()
  }

  func testCancellationBeforeReadingAndAfterDecodePreservesSourcesAndCleansCopies() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let fixture = try SyntheticFixtureFactory.exactTwoCapture()
    let urls = try files.write(fixture.captures.map(\.image))
    let originals = try urls.map { try Data(contentsOf: $0) }
    XCTAssertThrowsError(try PNGImportService(stagingParent: files.staging).importCaptures(from: urls, isCancelled: { true })) {
      XCTAssertEqual($0 as? PNGImportFailure, .cancelled)
    }
    let decoded = ImportCounter()
    let service = PNGImportService(stagingParent: files.staging) { url in
      let image = try PNGCodec.decodeOpaqueRGBA8(from: url)
      decoded.increment()
      return image
    }
    XCTAssertThrowsError(try service.importCaptures(from: urls, isCancelled: { decoded.value > 0 })) {
      XCTAssertEqual($0 as? PNGImportFailure, .cancelled)
    }
    XCTAssertEqual(decoded.value, 1)
    XCTAssertEqual(try urls.map { try Data(contentsOf: $0) }, originals)
    try files.assertClean()
  }

  func testCancellationDuringCopyRemovesPartialOwnedFile() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let image = try SyntheticFixtureFactory.document(width: 160, height: 200, seed: 77)
    let urls = try files.write([image, image])
    let originals = try urls.map { try Data(contentsOf: $0) }
    let checks = ImportCounter()
    let staging = files.staging
    XCTAssertThrowsError(try PNGImportService(stagingParent: staging).importCaptures(from: urls, isCancelled: {
      checks.increment()
      // Cancellation after the first stream block, observed from the owned destination.
      guard let enumerator = FileManager.default.enumerator(at: staging, includingPropertiesForKeys: [.fileSizeKey]) else { return false }
      for case let file as URL in enumerator {
        if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size >= 65_536 { return true }
      }
      return false
    })) {
      XCTAssertEqual($0 as? PNGImportFailure, .cancelled)
    }
    XCTAssertGreaterThan(checks.value, 3)
    XCTAssertEqual(try urls.map { try Data(contentsOf: $0) }, originals)
    try files.assertClean()
  }

  func testDecodedGeometryMustMatchPreflightAndFailureCleansStaging() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let image = try SyntheticFixtureFactory.document(width: 8, height: 8, seed: 7)
    let urls = try files.write([image, image])
    let wrong = try RasterImage(width: 1, height: 1, pixels: [255, 255, 255, 255])
    XCTAssertThrowsError(try PNGImportService(stagingParent: files.staging, decode: { _ in wrong }).importCaptures(from: urls)) {
      XCTAssertEqual($0 as? PNGImportFailure, .codec(.decodeFailed(urls[0].lastPathComponent)))
    }
    try files.assertClean()
  }

  func testBasenamesAreSanitizedWithoutLosingOriginalFiles() throws {
    let files = try ImportFiles()
    defer { files.remove() }
    let image = try RasterImage(width: 2, height: 2, pixels: Array(repeating: 255, count: 16))
    let source = files.root.appendingPathComponent("capture\n\u{202E}photo.png")
    let bytes = Data(PurePNGCodec.encode(image))
    try bytes.write(to: source)
    let captures = try PNGImportService(stagingParent: files.staging).importCaptures(from: [source, source])
    XCTAssertEqual(captures.map(\.sourceName), ["capture__photo.png", "capture__photo.png"])
    XCTAssertEqual(try Data(contentsOf: source), bytes)
    XCTAssertFalse(captures[0].sourceName.contains(files.root.path))
    try files.assertClean()
  }
}

private final class ImportCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0
  var value: Int { lock.withLock { count } }
  func increment() { lock.withLock { count += 1 } }
}

private struct ImportFiles {
  let root: URL
  let staging: URL
  let sentinel: URL

  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent("import-tests-\(UUID().uuidString)", isDirectory: true)
    staging = root.appendingPathComponent("staging", isDirectory: true)
    sentinel = root.appendingPathComponent("keep.txt")
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
    try Data("never delete this".utf8).write(to: sentinel)
  }

  func write(_ images: [RasterImage]) throws -> [URL] {
    try writeBytes(images.map(PurePNGCodec.encode))
  }

  func writeBytes(_ files: [[UInt8]], prefix: String = "capture") throws -> [URL] {
    try files.enumerated().map { index, bytes in
      let url = root.appendingPathComponent("\(prefix)-\(index).png")
      try Data(bytes).write(to: url, options: .withoutOverwriting)
      return url
    }
  }

  func assertClean(file: StaticString = #filePath, line: UInt = #line) throws {
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: staging.path), [], file: file, line: line)
    XCTAssertEqual(try Data(contentsOf: sentinel), Data("never delete this".utf8), file: file, line: line)
  }

  func remove() { try? FileManager.default.removeItem(at: root) }
}

private func bigEndian(_ value: UInt32) -> [UInt8] {
  [UInt8(truncatingIfNeeded: value >> 24), UInt8(truncatingIfNeeded: value >> 16),
   UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
}

private func pngChunk(_ type: String, _ bytes: [UInt8]) -> [UInt8] {
  let checked = Array(type.utf8) + bytes
  var crc: UInt32 = 0xffff_ffff
  for byte in checked {
    crc ^= UInt32(byte)
    for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xedb8_8320 : crc >> 1 }
  }
  return bigEndian(UInt32(bytes.count)) + checked + bigEndian(crc ^ 0xffff_ffff)
}
