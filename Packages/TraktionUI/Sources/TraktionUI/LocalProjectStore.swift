import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum LocalProjectFailure: Error, Equatable, Sendable {
  case unsupportedVersion(Int)
  case invalidContainer
  case invalidEvidence
  case invalidName
  case missingOriginals
  case destinationExists
  case unsupportedLocation
  case resourceLimit
  case cancelled
  case fileAccess
  case cleanupFailed(saved: Bool)

  public var message: String {
    switch self {
    case .unsupportedVersion: return "This project uses an unsupported format version."
    case .invalidContainer: return "The project is incomplete, corrupt, or contains invalid captures."
    case .invalidEvidence: return "The saved reconstruction evidence could not be reproduced from its original captures."
    case .invalidName: return "Use 1–80 letters, numbers, spaces, hyphens or underscores. Some characters require a shorter name."
    case .missingOriginals: return "Original PNG bytes are unavailable. Import the captures again before saving."
    case .destinationExists: return "An item already exists with this name. Choose another name."
    case .unsupportedLocation: return "This location cannot safely save a project. Choose the local TRAKTION folder or another supported folder on this device."
    case .resourceLimit: return "The project and current workspace exceed the memory or file-size allowance. Reset the workspace or choose a smaller project."
    case .cancelled: return "Project operation cancelled."
    case .cleanupFailed(let saved): return saved
      ? "The project was saved, but its temporary copy could not be removed."
      : "Private temporary project copies could not be removed. Your current workspace was kept."
    case .fileAccess: return "The selected project or folder could not be accessed."
    }
  }
}

/// Cancellation and the atomic filesystem commit share one lock. Once committed,
/// cancellation cannot relabel the operation as cancelled or imply unchanged disk.
public final class LocalProjectCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false
  private var committed = false
  public init() {}
  public var isCancelled: Bool { lock.withLock { cancelled } }
  public var didCommit: Bool { lock.withLock { committed } }
  public func cancel() { lock.withLock { if !committed { cancelled = true } } }
  func commit(_ action: () throws -> Void) throws {
    try lock.withLock {
      guard !cancelled else { throw LocalProjectFailure.cancelled }
      try action()
      committed = true
    }
  }
  func check() throws { if isCancelled { throw LocalProjectFailure.cancelled } }
}

public struct LocalProjectSnapshot: Sendable {
  public let captures: [CaptureAsset]
  public let originalPlan: ReconstructionPlan
  public let committedPlan: ReconstructionPlan
  public init(captures: [CaptureAsset], originalPlan: ReconstructionPlan, committedPlan: ReconstructionPlan) {
    self.captures = captures; self.originalPlan = originalPlan; self.committedPlan = committedPlan
  }
}

public struct LoadedLocalProject: Sendable {
  public let captures: [CaptureAsset]
  public let result: ReconstructionResult
  public let document: SeamEditingDocument
}

public protocol LocalProjectWorking: Sendable {
  func save(_ snapshot: LocalProjectSnapshot, folder: URL, name: String,
    cancellation: LocalProjectCancellation) throws -> URL
  func open(_ url: URL, retainedRasterBytes: Int, retainedEncodedBytes: Int,
    cancellation: LocalProjectCancellation) throws -> LoadedLocalProject
}

/// Binary framing and file IO only. Reconstruction and edited pixel authority stay in Core.
public struct LocalProjectStore: LocalProjectWorking {
  static let magic = Data([84, 82, 65, 75, 84, 73, 79, 78]) // TRAKTION
  static let maximumManifestBytes = 65_536
  private let limits: PNGImportLimits
  private let decode: @Sendable (URL) throws -> RasterImage
  private let beforeCommit: @Sendable () throws -> Void
  private let afterCommit: @Sendable () -> Void
  private let removeOwned: @Sendable (URL) throws -> Void
  private let openStagingParent: URL

  struct Manifest: Codable, Sendable {
    let captures: [Entry]
    let automaticPlan: ReconstructionPlan
    let committedPlan: ReconstructionPlan
  }
  struct Entry: Codable, Sendable {
    let id: CaptureID
    let name: String
    let byteCount: Int
    let width: Int
    let height: Int
  }

  public init(limits: PNGImportLimits = PNGImportLimits()) {
    self.init(limits: limits, decode: PNGCodec.decodeOpaqueRGBA8(from:))
  }
  init(limits: PNGImportLimits = PNGImportLimits(),
    decode: @escaping @Sendable (URL) throws -> RasterImage,
    beforeCommit: @escaping @Sendable () throws -> Void = {},
    afterCommit: @escaping @Sendable () -> Void = {},
    removeOwned: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) },
    openStagingParent: URL = FileManager.default.temporaryDirectory) {
    self.limits = limits; self.decode = decode
    self.beforeCommit = beforeCommit; self.afterCommit = afterCommit
    self.removeOwned = removeOwned
    self.openStagingParent = openStagingParent
  }

  public static func filename(_ name: String) throws -> String {
    let stem = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1...80).contains(stem.count), stem.unicodeScalars.allSatisfy({
      CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" || $0 == "_"
    }) else { throw LocalProjectFailure.invalidName }
    let filename = stem + ".traktion"
    // Keep the complete component portable to filesystems with a 255-byte limit.
    // Character count alone admits longer names containing non-BMP letters.
    guard filename.utf8.count <= 255 else { throw LocalProjectFailure.invalidName }
    return filename
  }

  public func save(_ snapshot: LocalProjectSnapshot, folder: URL, name: String,
    cancellation: LocalProjectCancellation = .init()) throws -> URL {
    do {
      try cancellation.check()
      let filename = try Self.filename(name)
      guard folder.isFileURL else { throw LocalProjectFailure.fileAccess }
      try validateSnapshot(snapshot)
      let entries = snapshot.captures.map {
        Entry(id: $0.id, name: $0.sourceName, byteCount: $0.originalPNG!.count,
          width: $0.image.width, height: $0.image.height)
      }
      let manifest = try JSONEncoder().encode(Manifest(captures: entries,
        automaticPlan: snapshot.originalPlan, committedPlan: snapshot.committedPlan))
      guard manifest.count <= Self.maximumManifestBytes else { throw LocalProjectFailure.resourceLimit }
      let destination = folder.appendingPathComponent(filename, isDirectory: false)
      #if os(iOS) || os(macOS)
      let accessed = folder.startAccessingSecurityScopedResource()
      defer { if accessed { folder.stopAccessingSecurityScopedResource() } }
      var coordinationError: NSError?
      var result: Result<URL, Error>?
      NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: destination,
        options: [], error: &coordinationError) { coordinatedURL in
        result = Result { try write(snapshot, manifest: manifest, destination: coordinatedURL,
          cancellation: cancellation) }
      }
      // Once the coordinated accessor committed, its result is authoritative.
      // Never reinterpret a completed disk change as an unchanged failed save.
      guard let result else { throw LocalProjectFailure.fileAccess }
      return try result.get()
      #else
      return try write(snapshot, manifest: manifest, destination: destination,
        cancellation: cancellation)
      #endif
    } catch let failure as LocalProjectFailure { throw failure }
    catch { throw LocalProjectFailure.fileAccess }
  }

  public func open(_ url: URL, retainedRasterBytes: Int = 0, retainedEncodedBytes: Int = 0,
    cancellation: LocalProjectCancellation = .init()) throws -> LoadedLocalProject {
    do {
      try cancellation.check()
      guard url.isFileURL else { throw LocalProjectFailure.fileAccess }
      #if os(iOS) || os(macOS)
      let accessed = url.startAccessingSecurityScopedResource()
      defer { if accessed { url.stopAccessingSecurityScopedResource() } }
      var coordinationError: NSError?
      var result: Result<LoadedLocalProject, Error>?
      NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url,
        options: .withoutChanges, error: &coordinationError) { readableURL in
        result = Result { try read(readableURL, retainedRasterBytes: retainedRasterBytes,
          retainedEncodedBytes: retainedEncodedBytes, cancellation: cancellation) }
      }
      guard coordinationError == nil, let result else { throw LocalProjectFailure.fileAccess }
      return try result.get()
      #else
      return try read(url, retainedRasterBytes: retainedRasterBytes,
        retainedEncodedBytes: retainedEncodedBytes, cancellation: cancellation)
      #endif
    } catch let failure as LocalProjectFailure { throw failure }
    catch is DecodingError { throw LocalProjectFailure.invalidContainer }
    catch let failure as PNGImportFailure {
      switch failure {
      case .fileAccess: throw LocalProjectFailure.fileAccess
      case .cancelled: throw LocalProjectFailure.cancelled
      case .resourceLimitExceeded: throw LocalProjectFailure.resourceLimit
      case .codec(let codec): throw projectFailure(for: codec)
      case .cleanupFailed: throw LocalProjectFailure.cleanupFailed(saved: false)
      case .countOutOfRange, .invalidFile, .incompatibleWidth:
        throw LocalProjectFailure.invalidContainer
      }
    } catch let failure as PNGCodecError { throw projectFailure(for: failure) }
    catch {
      // Filesystem/provider/staging failures must not accuse valid saved data of
      // corruption. Content refusal is explicit above or in framing validation.
      throw LocalProjectFailure.fileAccess
    }
  }

  private func projectFailure(for codec: PNGCodecError) -> LocalProjectFailure {
    switch codec {
    case .fileNotFound, .outputExists, .encodeFailed, .unsupportedPlatform:
      return .fileAccess
    case .resourceLimitExceeded: return .resourceLimit
    case .unsupportedFormat, .unsupportedTransparency, .decodeFailed:
      return .invalidContainer
    }
  }

  private func validateSnapshot(_ snapshot: LocalProjectSnapshot) throws {
    guard (2...10).contains(snapshot.captures.count),
      Set(snapshot.captures.map(\.id)).count == snapshot.captures.count,
      snapshot.captures.map(\.id) == snapshot.originalPlan.placements.map(\.captureID)
    else { throw LocalProjectFailure.invalidEvidence }
    var total = 0
    for capture in snapshot.captures {
      guard let bytes = capture.originalPNG else { throw LocalProjectFailure.missingOriginals }
      try validateIdentity(id: capture.id, name: capture.sourceName)
      guard bytes.count > 0, bytes.count <= limits.maximumEncodedBytesPerFile else {
        throw LocalProjectFailure.resourceLimit
      }
      total = try adding(total, bytes.count, maximum: limits.maximumTotalEncodedBytes)
    }
    do { _ = try SeamEditingDocument(originalPlan: snapshot.originalPlan,
      committedPlan: snapshot.committedPlan, captures: snapshot.captures) }
    catch { throw LocalProjectFailure.invalidEvidence }
  }

  private func write(_ snapshot: LocalProjectSnapshot, manifest: Data, destination: URL,
    cancellation: LocalProjectCancellation) throws -> URL {
    try cancellation.check()
    try requireAbsentDestination(destination)
    // A writer with access to the chosen folder must never be able to replace
    // the source pathname between flushing it and publishing its hard link.
    let privateParent = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
    let selectedFolder = destination.deletingLastPathComponent().resolvingSymlinksInPath()
    guard !privateParent.pathComponents.starts(with: selectedFolder.pathComponents) else {
      throw LocalProjectFailure.unsupportedLocation
    }
    let stage = privateParent.appendingPathComponent("traktion-save-\(UUID().uuidString)", isDirectory: true)
    // mkdir is exclusive: an existing directory must never become ours to clean.
    guard mkdir(stage.path, mode_t(0o700)) == 0 else { throw LocalProjectFailure.fileAccess }
    return try withCleanup(stage, cancellation: cancellation) {
      let temporary = stage.appendingPathComponent("project.tmp")
      #if canImport(Darwin)
      let descriptor = Darwin.open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o600))
      #else
      let descriptor = Glibc.open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o600))
      #endif
      guard descriptor >= 0 else { throw LocalProjectFailure.fileAccess }
      let output = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
      defer { try? output.close() }
      try output.write(contentsOf: Self.magic + Self.uint32(1) + Self.uint32(UInt32(manifest.count)))
      try output.write(contentsOf: manifest)
      for capture in snapshot.captures {
        let bytes = capture.originalPNG!
        var offset = 0
        while offset < bytes.count {
          try cancellation.check()
          let end = min(offset + 65_536, bytes.count)
          try output.write(contentsOf: bytes[offset..<end])
          offset = end
        }
      }
      try output.synchronize()
      try output.close()
      try beforeCommit()
      try cancellation.commit {
        // The atomic no-clobber publication is the authority. A destination
        // appearing after the early check must be refused by link itself.
        guard link(temporary.path, destination.path) == 0 else {
          let failure = errno
          if failure == EEXIST { throw LocalProjectFailure.destinationExists }
          if failure == EXDEV || failure == ENOTSUP || failure == EOPNOTSUPP {
            throw LocalProjectFailure.unsupportedLocation
          }
          throw LocalProjectFailure.fileAccess
        }
      }
      afterCommit()
      return destination
    }
  }

  private func requireAbsentDestination(_ url: URL) throws {
    var info = stat()
    if lstat(url.path, &info) == 0 { throw LocalProjectFailure.destinationExists }
    guard errno == ENOENT else { throw LocalProjectFailure.fileAccess }
  }

  private func read(_ url: URL, retainedRasterBytes: Int, retainedEncodedBytes: Int,
    cancellation: LocalProjectCancellation) throws -> LoadedLocalProject {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw LocalProjectFailure.invalidContainer
    }
    let input = try FileHandle(forReadingFrom: url)
    defer { try? input.close() }
    let totalSize = try input.seekToEnd()
    guard totalSize <= UInt64(max(0, limits.maximumTotalEncodedBytes)) + UInt64(Self.maximumManifestBytes + 16) else {
      throw LocalProjectFailure.resourceLimit
    }
    try input.seek(toOffset: 0)
    let header = try exact(input, count: 16)
    guard header.prefix(8) == Self.magic else { throw LocalProjectFailure.invalidContainer }
    let version = Self.integer(header, offset: 8)
    guard version == 1 else { throw LocalProjectFailure.unsupportedVersion(version) }
    let manifestLength = Self.integer(header, offset: 12)
    guard manifestLength > 0 else { throw LocalProjectFailure.invalidContainer }
    guard manifestLength <= Self.maximumManifestBytes else { throw LocalProjectFailure.resourceLimit }
    let manifest = try JSONDecoder().decode(Manifest.self, from: exact(input, count: manifestLength))
    guard (2...10).contains(manifest.captures.count),
      Set(manifest.captures.map(\.id)).count == manifest.captures.count,
      manifest.captures.map(\.id) == manifest.automaticPlan.placements.map(\.captureID)
    else { throw LocalProjectFailure.invalidContainer }
    var encoded = retainedEncodedBytes
    guard encoded >= 0, retainedRasterBytes >= 0 else { throw LocalProjectFailure.resourceLimit }
    var payloadBytes = 0
    for entry in manifest.captures {
      try validateIdentity(id: entry.id, name: entry.name)
      guard entry.byteCount > 0 else { throw LocalProjectFailure.invalidContainer }
      guard entry.byteCount <= limits.maximumEncodedBytesPerFile else {
        throw LocalProjectFailure.resourceLimit
      }
      encoded = try adding(encoded, entry.byteCount, maximum: limits.maximumTotalEncodedBytes)
      payloadBytes = try adding(payloadBytes, entry.byteCount, maximum: limits.maximumTotalEncodedBytes)
    }
    guard UInt64(payloadBytes) + UInt64(manifestLength + 16) == totalSize else {
      throw LocalProjectFailure.invalidContainer
    }
    let stage = openStagingParent.appendingPathComponent("traktion-project-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    return try withCleanup(stage, cancellation: cancellation) {
      var staged: [URL] = []
      var pixels = 0
      var thumbnailBytes = 0
      for (index, entry) in manifest.captures.enumerated() {
        try cancellation.check()
        let path = stage.appendingPathComponent("\(index).png")
        guard FileManager.default.createFile(atPath: path.path, contents: nil,
          attributes: [.posixPermissions: 0o600]) else { throw LocalProjectFailure.fileAccess }
        let output = try FileHandle(forWritingTo: path)
        do {
          var remaining = entry.byteCount
          while remaining > 0 {
            try cancellation.check()
            let chunk = try exact(input, count: min(65_536, remaining))
            try output.write(contentsOf: chunk)
            remaining -= chunk.count
          }
          try output.close()
        } catch { try? output.close(); throw error }
        let metadata = try PNGMetadata.inspect(from: path,
          maximumEncodedBytes: limits.maximumEncodedBytesPerFile,
          isCancelled: { cancellation.isCancelled })
        guard metadata.width == entry.width, metadata.height == entry.height,
          entry.width == manifest.captures[0].width else { throw LocalProjectFailure.invalidContainer }
        pixels = try adding(pixels, metadata.pixelCount, maximum: limits.maximumTotalInputPixels)
        thumbnailBytes = try adding(thumbnailBytes, min(metadata.pixelCount, 224 * 224) * 8,
          maximum: limits.maximumRetainedRasterBytes)
        staged.append(path)
      }
      guard try input.read(upToCount: 1)?.isEmpty != false else { throw LocalProjectFailure.invalidContainer }
      // Before decode/engine: originals + worst-case output + thumbnails/display
      // copies + committed result preview/display, while old workspace remains owned.
      var admitted = retainedRasterBytes
      for bytes in [try multiplied(pixels, 8), thumbnailBytes, min(pixels, 1_048_576) * 8] {
        admitted = try adding(admitted, bytes, maximum: limits.maximumRetainedRasterBytes)
      }
      var captures: [CaptureAsset] = []
      for (entry, path) in zip(manifest.captures, staged) {
        try cancellation.check()
        let raster: RasterImage
        #if canImport(ObjectiveC)
        raster = try autoreleasepool { try decode(path) }
        #else
        raster = try decode(path)
        #endif
        guard raster.width == entry.width, raster.height == entry.height else {
          throw LocalProjectFailure.invalidContainer
        }
        captures.append(CaptureAsset(id: entry.id, sourceName: entry.name,
          image: raster, originalPNG: try Data(contentsOf: path)))
      }
      let restored: RestoredProjectReconstruction
      do {
        restored = try ProjectRestorer().restore(captures: captures,
          automaticPlan: manifest.automaticPlan, committedPlan: manifest.committedPlan,
          isCancelled: { cancellation.isCancelled })
      } catch ProjectRestorationFailure.cancelled { throw LocalProjectFailure.cancelled }
      catch { throw LocalProjectFailure.invalidEvidence }
      return LoadedLocalProject(captures: captures, result: restored.result, document: restored.document)
    }
  }

  private func withCleanup<T>(_ owned: URL, cancellation: LocalProjectCancellation,
    body: () throws -> T) throws -> T {
    let result = Result { try body() }
    var info = stat()
    if lstat(owned.path, &info) == 0 {
      do { try removeOwned(owned) }
      catch { throw LocalProjectFailure.cleanupFailed(saved: cancellation.didCommit) }
    } else if errno != ENOENT {
      throw LocalProjectFailure.cleanupFailed(saved: cancellation.didCommit)
    }
    return try result.get()
  }

  private func validateIdentity(id: CaptureID, name: String) throws {
    guard !id.rawValue.isEmpty, id.rawValue.utf8.count <= 180,
      !name.isEmpty, name.utf8.count <= 180,
      !name.contains("/"), !name.contains("\\"), name != ".", name != "..",
      (id.rawValue + name).unicodeScalars.allSatisfy({
        !CharacterSet.controlCharacters.contains($0) && !CharacterSet.illegalCharacters.contains($0)
          && !(0x202A...0x202E).contains($0.value) && !(0x2066...0x2069).contains($0.value)
      }) else { throw LocalProjectFailure.invalidContainer }
  }
  private func adding(_ a: Int, _ b: Int, maximum: Int) throws -> Int {
    let (sum, overflow) = a.addingReportingOverflow(b)
    guard a >= 0, b >= 0, !overflow, sum <= maximum else { throw LocalProjectFailure.resourceLimit }
    return sum
  }
  private func multiplied(_ a: Int, _ b: Int) throws -> Int {
    let (value, overflow) = a.multipliedReportingOverflow(by: b)
    guard !overflow, value >= 0 else { throw LocalProjectFailure.resourceLimit }
    return value
  }
  private func exact(_ file: FileHandle, count: Int) throws -> Data {
    let data = try file.read(upToCount: count) ?? Data()
    guard data.count == count else { throw LocalProjectFailure.invalidContainer }
    return data
  }
  static func uint32(_ value: UInt32) -> Data {
    Data([UInt8(value >> 24), UInt8(truncatingIfNeeded: value >> 16),
      UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)])
  }
  static func integer(_ data: Data, offset: Int) -> Int {
    Int(data[offset]) << 24 | Int(data[offset + 1]) << 16 | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
  }
}
