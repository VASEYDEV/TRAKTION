import Foundation
import TraktionCore
import TraktionDomain
import TraktionVision

public enum PNGExportFailure: Error, Equatable, Sendable {
  case invalidName, invalidEvidence, resourceLimit, cancelled, destinationExists, unsupportedLocation, fileAccess
  case cleanupFailed(saved: Bool)
  public var message: String {
    switch self {
    case .invalidName: return LocalProjectFailure.invalidName.message
    case .invalidEvidence: return "The committed reconstruction cannot be exported safely."
    case .resourceLimit: return "The result and workspace exceed the PNG export allowance."
    case .cancelled: return "PNG export cancelled."
    case .destinationExists: return "An item already exists with this name. Choose another name."
    case .unsupportedLocation: return "This location cannot safely save a PNG. Choose the local TRAKTION folder on this device."
    case .fileAccess: return "The PNG destination could not be accessed or written."
    case .cleanupFailed(let saved): return saved
      ? "The PNG was exported, but its private temporary copy could not be removed."
      : "Export did not finish and its private temporary copy could not be removed."
    }
  }
}

public protocol PNGExportWorking: Sendable {
  func export(_ snapshot: LocalProjectSnapshot, folder: URL, name: String,
    retainedRasterBytes: Int, cancellation: LocalProjectCancellation) throws -> URL
}

public struct PNGExportStore: PNGExportWorking {
  private let publisher: AtomicOutputPublisher
  private let maximumWorkingBytes: Int
  public init(maximumWorkingBytes: Int = 256 * 1_048_576) {
    self.maximumWorkingBytes = maximumWorkingBytes; publisher = AtomicOutputPublisher()
  }
  init(publisher: AtomicOutputPublisher, maximumWorkingBytes: Int = 256 * 1_048_576) {
    self.publisher = publisher; self.maximumWorkingBytes = maximumWorkingBytes
  }
  public static func filename(_ name: String) throws -> String {
    let stem = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1...80).contains(stem.count), stem.unicodeScalars.allSatisfy({
      CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" || $0 == "_"
    }), (stem + ".png").utf8.count <= 255 else { throw PNGExportFailure.invalidName }
    return stem + ".png"
  }
  public func export(_ snapshot: LocalProjectSnapshot, folder: URL, name: String,
    retainedRasterBytes: Int, cancellation: LocalProjectCancellation = .init()) throws -> URL {
    do {
      try cancellation.check()
      let name = try Self.filename(name)
      guard folder.isFileURL else { throw PNGExportFailure.fileAccess }
      var sourceBytes = 0
      for capture in snapshot.captures {
        let (sum, overflow) = sourceBytes.addingReportingOverflow(capture.image.pixels.count)
        guard !overflow else { throw PNGExportFailure.resourceLimit }
        sourceBytes = sum
      }
      guard retainedRasterBytes >= 0 else { throw PNGExportFailure.resourceLimit }
      let admission = try PNGStreamAdmission(width: snapshot.committedPlan.outputWidth,
        height: snapshot.committedPlan.outputHeight, retainedBytes: max(sourceBytes, retainedRasterBytes),
        maximumWorkingBytes: maximumWorkingBytes)
      let renderer: PlannedRasterRenderer
      do {
        let document = try SeamEditingDocument(originalPlan: snapshot.originalPlan,
          committedPlan: snapshot.committedPlan, captures: snapshot.captures)
        renderer = try PlannedRasterRenderer(plan: document.plan, captures: snapshot.captures)
      } catch { throw PNGExportFailure.invalidEvidence }
      let destination = folder.appendingPathComponent(name)
      func publish(_ url: URL) throws -> URL {
        try publisher.publish(destination: url, cancellation: cancellation) { output in
          try PNGCodec.streamOpaqueRGBA8(admission, isCancelled: { cancellation.isCancelled },
            row: { try renderer.rgbaRow($0, isCancelled: { cancellation.isCancelled }) },
            write: { try output.write(contentsOf: $0) })
        }
      }
      #if os(iOS) || os(macOS)
      let accessed = folder.startAccessingSecurityScopedResource()
      defer { if accessed { folder.stopAccessingSecurityScopedResource() } }
      var coordinationError: NSError?
      var result: Result<URL, Error>?
      NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: destination,
        options: [], error: &coordinationError) { url in result = Result { try publish(url) } }
      guard let result else { throw PNGExportFailure.fileAccess }
      return try result.get()
      #else
      return try publish(destination)
      #endif
    } catch let failure as PNGExportFailure { throw failure }
    catch let failure as LocalProjectFailure {
      switch failure {
      case .cancelled: throw PNGExportFailure.cancelled
      case .destinationExists: throw PNGExportFailure.destinationExists
      case .unsupportedLocation: throw PNGExportFailure.unsupportedLocation
      case .cleanupFailed(let saved): throw PNGExportFailure.cleanupFailed(saved: saved)
      default: throw PNGExportFailure.fileAccess
      }
    } catch let failure as PNGStreamFailure {
      switch failure {
      case .resourceLimit: throw PNGExportFailure.resourceLimit
      case .cancelled: throw PNGExportFailure.cancelled
      case .malformedRow, .nonOpaque: throw PNGExportFailure.invalidEvidence
      }
    } catch SeamEditingFailure.cancelled { throw PNGExportFailure.cancelled }
    catch { throw PNGExportFailure.fileAccess }
  }
}
