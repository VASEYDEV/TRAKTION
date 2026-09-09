import Foundation
import TraktionDomain

/// Admission limits for owned encoded files and retained RGBA rasters, not process RSS.
public struct PNGImportLimits: Equatable, Sendable {
  public let maximumTotalInputPixels: Int
  public let maximumRetainedRasterBytes: Int
  public let maximumEncodedBytesPerFile: Int
  public let maximumTotalEncodedBytes: Int

  public init(
    maximumTotalInputPixels: Int = 33_554_432,
    maximumRetainedRasterBytes: Int = 268_435_456,
    maximumEncodedBytesPerFile: Int = 67_108_864,
    maximumTotalEncodedBytes: Int = 134_217_728
  ) {
    self.maximumTotalInputPixels = maximumTotalInputPixels
    self.maximumRetainedRasterBytes = maximumRetainedRasterBytes
    self.maximumEncodedBytesPerFile = maximumEncodedBytesPerFile
    self.maximumTotalEncodedBytes = maximumTotalEncodedBytes
  }
}

public enum PNGImportFailure: Error, Equatable, Sendable {
  case countOutOfRange(Int)
  case invalidFile(String)
  case codec(PNGCodecError)
  case incompatibleWidth(name: String, expected: Int, actual: Int)
  case resourceLimitExceeded(String)
  case cancelled
  case fileAccess(String)
  case cleanupFailed
}

extension PNGImportFailure: CustomStringConvertible {
  public var description: String {
    switch self {
    case .countOutOfRange(let count):
      return "Choose 2–10 PNG captures; this selection contains \(count)."
    case .invalidFile(let name):
      return "Choose a regular PNG file: \(name)"
    case .codec(let failure):
      return failure.description
    case .incompatibleWidth(let name, let expected, let actual):
      return "\(name) is \(actual) pixels wide; all captures must be \(expected) pixels wide."
    case .resourceLimitExceeded(let reason):
      return "Import exceeds the workspace resource limit: \(reason)"
    case .cancelled:
      return "Import cancelled."
    case .cleanupFailed:
      return "Temporary import copies could not be removed. Original files are unchanged."
    case .fileAccess(let name):
      return "Could not read or prepare the selected file: \(name)"
    }
  }
}

/// Synchronous worker service. A complete validated batch is the only published result.
/// Original URLs are opened read-only; owned copies are removed before returning.
public struct PNGImportService: Sendable {
  public let limits: PNGImportLimits
  private let stagingParent: URL
  private let decode: @Sendable (URL) throws -> RasterImage

  public init(limits: PNGImportLimits = PNGImportLimits()) {
    self.init(
      limits: limits,
      stagingParent: FileManager.default.temporaryDirectory,
      decode: PNGCodec.decodeOpaqueRGBA8(from:)
    )
  }

  // Internal seam for verifying stage ownership and admission before decoding.
  init(
    limits: PNGImportLimits = PNGImportLimits(),
    stagingParent: URL,
    decode: @escaping @Sendable (URL) throws -> RasterImage = PNGCodec.decodeOpaqueRGBA8(from:)
  ) {
    self.limits = limits
    self.stagingParent = stagingParent
    self.decode = decode
  }

  public func importCaptures(
    from urls: [URL],
    retainedRasterBytes: Int = 0,
    isCancelled: @Sendable () -> Bool = { false }
  ) throws -> [CaptureAsset] {
    try checkCancellation(isCancelled)
    guard (2...10).contains(urls.count) else {
      throw PNGImportFailure.countOutOfRange(urls.count)
    }
    guard retainedRasterBytes >= 0,
      limits.maximumTotalInputPixels > 0,
      limits.maximumRetainedRasterBytes > 0,
      limits.maximumEncodedBytesPerFile > 0,
      limits.maximumTotalEncodedBytes > 0
    else {
      throw PNGImportFailure.resourceLimitExceeded("Invalid memory or file-size allowance.")
    }
    for url in urls where !url.isFileURL {
      throw PNGImportFailure.invalidFile(importName(url))
    }

    let directory = stagingParent.appendingPathComponent(
      "traktion-import-\(UUID().uuidString)", isDirectory: true
    )
    do {
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
      )
    } catch {
      throw PNGImportFailure.fileAccess("Temporary import storage")
    }

    let result: Result<[CaptureAsset], Error>
    do {
      result = .success(try stagedImport(
        urls, directory: directory, retainedRasterBytes: retainedRasterBytes,
        isCancelled: isCancelled
      ))
    } catch {
      result = .failure(error)
    }
    do {
      // Only this invocation's newly created directory is ever removed.
      try FileManager.default.removeItem(at: directory)
    } catch {
      throw PNGImportFailure.cleanupFailed
    }
    try checkCancellation(isCancelled)
    return try result.get()
  }

  private func stagedImport(
    _ urls: [URL], directory: URL, retainedRasterBytes: Int,
    isCancelled: @Sendable () -> Bool
  ) throws -> [CaptureAsset] {
    var staged: [(url: URL, name: String, metadata: PNGMetadata)] = []
    var totalEncoded = 0
    var totalPixels = 0
    for (index, source) in urls.enumerated() {
      try checkCancellation(isCancelled)
      let name = importName(source)
      let captureDirectory = directory.appendingPathComponent(String(index), isDirectory: true)
      let destination = captureDirectory.appendingPathComponent(name)
      do {
        try FileManager.default.createDirectory(
          at: captureDirectory, withIntermediateDirectories: false
        )
        let copied = try coordinatedCopy(
          from: source, to: destination,
          byteLimit: min(
            limits.maximumEncodedBytesPerFile, limits.maximumTotalEncodedBytes - totalEncoded
          ),
          isCancelled: isCancelled
        )
        totalEncoded += copied // Each copy is bounded by the remaining aggregate allowance.
      } catch let failure as PNGImportFailure {
        throw failure
      } catch {
        throw PNGImportFailure.fileAccess(name)
      }
      let metadata = try PNGMetadata.inspect(
        from: destination, maximumEncodedBytes: limits.maximumEncodedBytesPerFile,
        isCancelled: isCancelled
      )
      if let first = staged.first, metadata.width != first.metadata.width {
        throw PNGImportFailure.incompatibleWidth(
          name: name, expected: first.metadata.width, actual: metadata.width
        )
      }
      let (newTotal, overflow) = totalPixels.addingReportingOverflow(metadata.pixelCount)
      guard !overflow, newTotal <= limits.maximumTotalInputPixels else {
        throw PNGImportFailure.resourceLimitExceeded("The selected captures contain too many pixels.")
      }
      totalPixels = newTotal
      staged.append((destination, name, metadata))
    }

    let (newRasterBytes, byteOverflow) = totalPixels.multipliedReportingOverflow(by: 4)
    let (combinedBytes, retainedOverflow) = retainedRasterBytes.addingReportingOverflow(newRasterBytes)
    guard !byteOverflow, !retainedOverflow, combinedBytes <= limits.maximumRetainedRasterBytes else {
      throw PNGImportFailure.resourceLimitExceeded(
        "The selected captures and current workspace exceed the retained raster allowance."
      )
    }
    // No raster is decoded until every input and the complete batch have passed preflight.
    var captures: [CaptureAsset] = []
    for item in staged {
      try checkCancellation(isCancelled)
      let raster: RasterImage
      do {
        #if canImport(ObjectiveC)
          raster = try autoreleasepool { try decode(item.url) }
        #else
          raster = try decode(item.url)
        #endif
      } catch let failure as PNGCodecError {
        throw PNGImportFailure.codec(failure)
      } catch {
        throw PNGImportFailure.codec(.decodeFailed(item.name))
      }
      try checkCancellation(isCancelled)
      guard raster.width == item.metadata.width, raster.height == item.metadata.height else {
        throw PNGImportFailure.codec(.decodeFailed(item.name))
      }
      captures.append(CaptureAsset(
        id: CaptureID(UUID().uuidString), sourceName: item.name, image: raster
      ))
    }
    return captures
  }

  private func coordinatedCopy(
    from source: URL, to destination: URL, byteLimit: Int,
    isCancelled: @Sendable () -> Bool
  ) throws -> Int {
    #if os(iOS) || os(macOS)
      let accessed = source.startAccessingSecurityScopedResource()
      defer { if accessed { source.stopAccessingSecurityScopedResource() } }
      var coordinationError: NSError?
      var copyResult: Result<Int, Error>?
      let coordinator = NSFileCoordinator(filePresenter: nil)
      coordinator.coordinate(
        readingItemAt: source, options: .withoutChanges, error: &coordinationError
      ) { readableURL in
        copyResult = Result {
          try boundedCopy(
            from: readableURL, to: destination, byteLimit: byteLimit,
            name: importName(source), isCancelled: isCancelled
          )
        }
      }
      guard coordinationError == nil, let copyResult else {
        throw PNGImportFailure.fileAccess(importName(source))
      }
      return try copyResult.get()
    #else
      return try boundedCopy(
        from: source, to: destination, byteLimit: byteLimit,
        name: importName(source), isCancelled: isCancelled
      )
    #endif
  }

  private func boundedCopy(
    from source: URL, to destination: URL, byteLimit: Int, name: String,
    isCancelled: @Sendable () -> Bool
  ) throws -> Int {
    try checkCancellation(isCancelled)
    let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    guard values.isRegularFile == true else { throw PNGImportFailure.invalidFile(name) }
    guard byteLimit > 0, let fileSize = values.fileSize, fileSize >= 0, fileSize <= byteLimit else {
      throw PNGImportFailure.resourceLimitExceeded("Encoded file allowance exceeded by \(name).")
    }
    let input = try FileHandle(forReadingFrom: source)
    defer { try? input.close() }
    guard FileManager.default.createFile(
      atPath: destination.path, contents: nil, attributes: [.posixPermissions: 0o600]
    ) else { throw PNGImportFailure.fileAccess(name) }
    let output = try FileHandle(forWritingTo: destination)
    defer { try? output.close() }
    var copied = 0
    while true {
      try checkCancellation(isCancelled)
      // One extra byte detects a file growing beyond the allowance without copying it.
      let chunk = try input.read(upToCount: min(65_535, byteLimit - copied) + 1) ?? Data()
      guard !chunk.isEmpty else { break }
      guard chunk.count <= byteLimit - copied else {
        throw PNGImportFailure.resourceLimitExceeded("Encoded file allowance exceeded by \(name).")
      }
      try output.write(contentsOf: chunk)
      copied += chunk.count
    }
    return copied
  }
}

func checkCancellation(_ isCancelled: @Sendable () -> Bool) throws {
  if isCancelled() { throw PNGImportFailure.cancelled }
}

/// Basenames only: strip control/bidi characters and separators, and bound UTF-8 length.
func importName(_ url: URL) -> String {
  var result = ""
  for character in url.lastPathComponent {
    let safe = character.unicodeScalars.allSatisfy {
      !CharacterSet.controlCharacters.contains($0)
        && !CharacterSet.illegalCharacters.contains($0)
        && $0.value != 47 && $0.value != 92
        && !(0x202A...0x202E).contains($0.value)
        && !(0x2066...0x2069).contains($0.value)
    }
    let next = safe ? String(character) : "_"
    if result.utf8.count + next.utf8.count > 180 { break }
    result += next
  }
  return result.isEmpty || result == "." || result == ".." ? "capture.png" : result
}
