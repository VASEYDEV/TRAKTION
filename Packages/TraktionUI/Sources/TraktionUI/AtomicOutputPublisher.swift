import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Shared create-only publication for projects and PNGs. Failures are translated
/// by each caller; no destination-folder staging or non-atomic copy fallback.
struct AtomicOutputPublisher: Sendable {
  var beforeCommit: @Sendable () throws -> Void = {}
  var afterCommit: @Sendable () -> Void = {}
  var removeOwned: @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }

  func publish(destination: URL, cancellation: LocalProjectCancellation,
    write: (FileHandle) throws -> Void) throws -> URL {
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
    let result = Result { () throws -> URL in
      let temporary = stage.appendingPathComponent("project.tmp")
      #if canImport(Darwin)
      let descriptor = Darwin.open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o600))
      #else
      let descriptor = Glibc.open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o600))
      #endif
      guard descriptor >= 0 else { throw LocalProjectFailure.fileAccess }
      let output = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
      defer { try? output.close() }
      try write(output)
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
    var info = stat()
    if lstat(stage.path, &info) == 0 {
      do { try removeOwned(stage) }
      catch { throw LocalProjectFailure.cleanupFailed(saved: cancellation.didCommit) }
    } else if errno != ENOENT {
      throw LocalProjectFailure.cleanupFailed(saved: cancellation.didCommit)
    }
    return try result.get()
  }

  private func requireAbsentDestination(_ url: URL) throws {
    var info = stat()
    if lstat(url.path, &info) == 0 { throw LocalProjectFailure.destinationExists }
    guard errno == ENOENT else { throw LocalProjectFailure.fileAccess }
  }

}
