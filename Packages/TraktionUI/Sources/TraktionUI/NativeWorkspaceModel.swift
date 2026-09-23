import Dispatch
import Foundation
import Observation
import TraktionCore
import TraktionDomain
import TraktionVision

public enum NativeWorkspaceOperation: Equatable, Sendable {
  case importing
  case reconstructing
  case openingProject
  case exportingPNG
  case savingProject
}

@MainActor
@Observable
public final class NativeWorkspaceModel {
  let inspection: NativeInspectionModel

  public private(set) var captures: [CaptureAsset] = []
  public private(set) var thumbnails: [CaptureID: RasterImage] = [:]
  public private(set) var result: ReconstructionResult?
  public var resultPreview: RasterImage? { inspection.editing.preview }
  public var isModified: Bool { inspection.editing.isModified }
  public private(set) var projectMessage: String?
  public private(set) var failure: NativeWorkspaceFailure?
  public private(set) var operation: NativeWorkspaceOperation?
  public private(set) var isCancelling = false
  public private(set) var orderConfirmed = false

  @ObservationIgnored private let worker: any NativeWorkspaceWorking
  @ObservationIgnored private let exports: any PNGExportWorking
  @ObservationIgnored private let projects: any LocalProjectWorking
  @ObservationIgnored private let limits: PNGImportLimits
  @ObservationIgnored private let queue = DispatchQueue(
    label: "dev.vasey.traktion.workspace", qos: .userInitiated
  )
  @ObservationIgnored private var activeJob: ActiveJob?

  private struct ActiveJob: Sendable {
    let id: UUID
    let token: NativeWorkspaceCancellation
    let previousFailure: NativeWorkspaceFailure?
    var wasReset = false
  }

  private struct ImportedBatch: Sendable {
    let captures: [CaptureAsset]
    let thumbnails: [CaptureID: RasterImage]
  }

  private struct ReconstructedBatch: Sendable {
    let result: ReconstructionResult
    let preview: RasterImage
  }

  public init(
    worker: (any NativeWorkspaceWorking)? = nil,
    limits: PNGImportLimits = PNGImportLimits(),
    projects: (any LocalProjectWorking)? = nil,
    exports: (any PNGExportWorking)? = nil
  ) {
    self.worker = worker ?? NativeWorkspaceWorker(limits: limits)
    self.projects = projects ?? LocalProjectStore(limits: limits)
    self.exports = exports ?? PNGExportStore(maximumWorkingBytes: limits.maximumRetainedRasterBytes)
    self.limits = limits
    self.inspection = NativeInspectionModel()
  }

  init(worker: any NativeWorkspaceWorking, inspection: NativeInspectionModel) {
    self.worker = worker
    self.projects = LocalProjectStore()
    self.exports = PNGExportStore()
    self.limits = PNGImportLimits()
    self.inspection = inspection
  }

  public var isBusy: Bool { operation != nil || inspection.isRendering || inspection.editing.isRendering }

  public var canSaveProject: Bool {
    !isBusy && result != nil && inspection.editing.document != nil
      && inspection.editing.draft == nil && captures.allSatisfy { $0.originalPNG != nil }
  }

  public var canExportPNG: Bool {
    !isBusy && result != nil && inspection.editing.document != nil && inspection.editing.draft == nil
  }

  public var canReconstruct: Bool {
    !isBusy && orderConfirmed && (2...10).contains(captures.count) && result == nil
  }

  public var statusMessage: String {
    if isCancelling {
      return "Cancelling. Waiting for image work to finish before another operation."
    }
    if inspection.editing.isRendering { return "Updating the adjusted result…" }
    if inspection.isRendering { return "Updating pixel inspection…" }
    switch operation {
    case .importing: return "Reading and validating PNG captures…"
    case .reconstructing: return "Reconstructing on this device…"
    case .openingProject: return "Validating and reopening the local project…"
    case .exportingPNG: return "Exporting committed pixels to PNG…"
    case .savingProject: return "Saving original captures and committed seams…"
    case nil:
      if result != nil { return isModified ? "Seams adjusted. Original files and registration evidence are unchanged." : "Reconstruction complete. Original files are unchanged." }
      if captures.isEmpty { return "Choose 2–10 overlapping PNG captures to begin." }
      if captures.count < 2 { return "At least two captures are needed. Import a new batch." }
      return orderConfirmed
        ? "Order confirmed. Ready to reconstruct."
        : "Check the top-to-bottom order, then confirm it."
    }
  }

  public var failureMessage: String? { failure?.message(captures: captures) }

  public func importCaptures(from urls: [URL]) {
    guard !isBusy else { return }
    inspection.close()
    let retainedBytes: Int
    do {
      retainedBytes = try ownedRasterBytes()
    } catch {
      failure = .importFailure(.resourceLimitExceeded("The current workspace is too large. Reset it before importing another batch."))
      return
    }
    let retainedEncoded = captures.reduce(0) { $0 + ($1.originalPNG?.count ?? 0) }
    let rasterBudget = limits.maximumRetainedRasterBytes
    let job = begin(.importing)
    let worker = self.worker
    queue.async { [weak self] in
      let outcome: Result<ImportedBatch, NativeWorkspaceFailure>
      do {
        let assets = try worker.importCaptures(
          from: urls, retainedRasterBytes: retainedBytes, retainedEncodedBytes: retainedEncoded,
          isCancelled: { job.token.isCancelled }
        )
        guard !job.token.isCancelled else { throw PNGImportFailure.cancelled }
        try NativeRasterPreview.admitThumbnails(
          assets, retainedBytes: retainedBytes, maximumBytes: rasterBudget
        )
        var previews: [CaptureID: RasterImage] = [:]
        for asset in assets {
          previews[asset.id] = try NativeRasterPreview.make(
            asset.image,
            maximumDimension: NativeRasterPreview.thumbnailDimension,
            maximumPixels: NativeRasterPreview.thumbnailDimension * NativeRasterPreview.thumbnailDimension,
            isCancelled: { job.token.isCancelled }
          )
        }
        outcome = .success(ImportedBatch(captures: assets, thumbnails: previews))
      } catch let error as PNGImportFailure {
        outcome = .failure(.importFailure(error))
      } catch {
        outcome = .failure(.unexpected)
      }
      Task { @MainActor [weak self] in
        self?.finishImport(id: job.id, outcome: outcome)
      }
    }
  }

  public func saveProject(folder: URL, name: String) {
    guard canSaveProject, let document = inspection.editing.document else { return }
    let snapshot = LocalProjectSnapshot(captures: captures,
      originalPlan: document.originalPlan, committedPlan: document.plan)
    let projects = self.projects
    let job = begin(.savingProject)
    queue.async { [weak self] in
      let outcome: Result<URL, NativeWorkspaceFailure>
      do { outcome = .success(try projects.save(snapshot, folder: folder, name: name,
        cancellation: job.token)) }
      catch let error as LocalProjectFailure { outcome = .failure(.project(error)) }
      catch { outcome = .failure(.unexpected) }
      Task { @MainActor [weak self] in
        guard let self, self.activeJob?.id == job.id else { return }
        // A committed save is a real disk change even if reset followed it.
        let committed = job.token.didCommit
        guard self.finishJob(id: job.id) || committed else {
          if case .failure(.project(.cleanupFailed(let saved))) = outcome {
            self.failure = .project(.cleanupFailed(saved: saved))
          }
          return
        }
        switch outcome {
        case .success(let url): self.projectMessage = "Saved \(url.lastPathComponent)."
        case .failure(let error): self.failure = error
        }
      }
    }
  }

  public func exportPNG(folder: URL, name: String) {
    guard canExportPNG, let document = inspection.editing.document else { return }
    inspection.close()
    let retained: Int
    do { retained = try ownedRasterBytes() }
    catch { failure = .export(.resourceLimit); return }
    let snapshot = LocalProjectSnapshot(captures: captures,
      originalPlan: document.originalPlan, committedPlan: document.plan)
    let exports = self.exports
    let job = begin(.exportingPNG)
    queue.async { [weak self] in
      let outcome: Result<URL, NativeWorkspaceFailure>
      do { outcome = .success(try exports.export(snapshot, folder: folder, name: name,
        retainedRasterBytes: retained, cancellation: job.token)) }
      catch let error as PNGExportFailure { outcome = .failure(.export(error)) }
      catch { outcome = .failure(.unexpected) }
      Task { @MainActor [weak self] in
        guard let self, self.activeJob?.id == job.id else { return }
        let committed = job.token.didCommit
        guard self.finishJob(id: job.id) || committed else {
          if case .failure(.export(.cleanupFailed(let saved))) = outcome {
            self.failure = .export(.cleanupFailed(saved: saved))
          }
          return
        }
        switch outcome {
        case .success(let url): self.projectMessage = "Exported \(url.lastPathComponent)."
        case .failure(let error): self.failure = error
        }
      }
    }
  }

  public func openProject(_ url: URL) {
    guard !isBusy else { return }
    inspection.close()
    let retained: Int
    do { retained = try ownedRasterBytes() }
    catch { failure = .project(.resourceLimit); return }
    let encoded = captures.reduce(0) { $0 + ($1.originalPNG?.count ?? 0) }
    let projects = self.projects
    let job = begin(.openingProject)
    queue.async { [weak self] in
      let outcome: Result<(LoadedLocalProject, [CaptureID: RasterImage], RasterImage), NativeWorkspaceFailure>
      do {
        let loaded = try projects.open(url, retainedRasterBytes: retained,
          retainedEncodedBytes: encoded, cancellation: job.token)
        try job.token.check()
        var thumbnails: [CaptureID: RasterImage] = [:]
        for capture in loaded.captures {
          thumbnails[capture.id] = try NativeRasterPreview.make(capture.image,
            maximumDimension: NativeRasterPreview.thumbnailDimension,
            maximumPixels: NativeRasterPreview.thumbnailDimension * NativeRasterPreview.thumbnailDimension,
            isCancelled: { job.token.isCancelled })
        }
        let preview = try SeamPreviewRenderer().render(plan: loaded.document.plan,
          captures: loaded.captures, isCancelled: { job.token.isCancelled })
        outcome = .success((loaded, thumbnails, preview))
      } catch let error as LocalProjectFailure { outcome = .failure(.project(error)) }
      catch { outcome = .failure(.unexpected) }
      Task { @MainActor [weak self] in
        guard let self, self.activeJob?.id == job.id else { return }
        guard self.finishJob(id: job.id) else {
          if case .failure(.project(.cleanupFailed(let saved))) = outcome {
            self.failure = .project(.cleanupFailed(saved: saved))
          }
          return
        }
        switch outcome {
        case .success(let (loaded, thumbnails, preview)):
          self.captures = loaded.captures
          self.thumbnails = thumbnails
          self.result = loaded.result
          self.inspection.editing.restore(document: loaded.document, captures: loaded.captures, preview: preview)
          self.orderConfirmed = true
          self.failure = nil
          self.projectMessage = "Opened \(url.lastPathComponent). Undo history starts with this session."
        case .failure(let error): self.failure = error
        }
      }
    }
  }

  public func confirmOrder() {
    guard !isBusy, (2...10).contains(captures.count) else { return }
    orderConfirmed = true
  }

  public func moveCapture(id: CaptureID, offset: Int) {
    guard !isBusy, offset == -1 || offset == 1,
      let source = captures.firstIndex(where: { $0.id == id })
    else { return }
    let destination = source + offset
    guard captures.indices.contains(destination) else { return }
    captures.swapAt(source, destination)
    invalidateReconstruction()
  }

  public func removeCapture(id: CaptureID) {
    guard !isBusy, captures.contains(where: { $0.id == id }) else { return }
    captures.removeAll { $0.id == id }
    thumbnails.removeValue(forKey: id)
    invalidateReconstruction()
  }

  public func reconstruct() {
    guard canReconstruct else { return }
    do {
      try validateReconstructionBudget()
    } catch let error as NativeWorkspaceFailure {
      failure = error
      return
    } catch {
      failure = .unexpected
      return
    }
    let assets = captures
    let job = begin(.reconstructing)
    let worker = self.worker
    queue.async { [weak self] in
      let outcome: Result<ReconstructedBatch, NativeWorkspaceFailure>
      do {
        let result = try worker.reconstruct(assets)
        guard !job.token.isCancelled else { throw PNGImportFailure.cancelled }
        let preview = try NativeRasterPreview.make(
          result.image,
          maximumDimension: NativeRasterPreview.maximumResultDimension,
          maximumPixels: NativeRasterPreview.maximumResultPixels,
          isCancelled: { job.token.isCancelled }
        )
        outcome = .success(ReconstructedBatch(result: result, preview: preview))
      } catch let error as ReconstructionFailure {
        outcome = .failure(.reconstruction(error))
      } catch let error as PNGImportFailure {
        outcome = .failure(.importFailure(error))
      } catch {
        outcome = .failure(.unexpected)
      }
      Task { @MainActor [weak self] in
        self?.finishReconstruction(id: job.id, outcome: outcome)
      }
    }
  }

  public func inspectResult() {
    guard !isBusy, let result else { return }
    do {
      try inspection.open(result: result, captures: captures,
        retainedBytes: ownedRasterBytes(), budget: limits.maximumRetainedRasterBytes)
    } catch {
      failure = .selection("There is not enough workspace raster memory for pixel inspection. The result and originals are unchanged.")
    }
  }

  public func cancel() {
    guard let job = activeJob else { inspection.editing.cancelRendering(); return }
    job.token.cancel()
    isCancelling = true
  }

  public func reset() {
    if activeJob != nil {
      cancel()
      activeJob?.wasReset = true
    }
    captures = []
    thumbnails = [:]
    projectMessage = nil
    invalidateReconstruction()
  }

  public func dismissFailure() {
    guard !isBusy else { return }
    failure = nil
  }

  public func reportPickerFailure(_ description: String) {
    guard !isBusy else { return }
    failure = .selection(description)
  }

  private func begin(_ operation: NativeWorkspaceOperation) -> ActiveJob {
    let job = ActiveJob(
      id: UUID(), token: NativeWorkspaceCancellation(), previousFailure: failure
    )
    activeJob = job
    self.operation = operation
    isCancelling = false
    failure = nil
    projectMessage = nil
    return job
  }

  private func finishImport(
    id: UUID, outcome: Result<ImportedBatch, NativeWorkspaceFailure>
  ) {
    guard activeJob?.id == id else { return }
    guard finishJob(id: id) else {
      // Cancellation suppresses image publication, but cleanup failures must
      // remain visible even after a reset because owned temporary copies may remain.
      if case .failure(.importFailure(.cleanupFailed)) = outcome {
        failure = .importFailure(.cleanupFailed)
      }
      return
    }
    switch outcome {
    case .success(let batch):
      captures = batch.captures
      thumbnails = batch.thumbnails
      invalidateReconstruction()
    case .failure(let error):
      failure = error
    }
  }

  private func finishReconstruction(
    id: UUID, outcome: Result<ReconstructedBatch, NativeWorkspaceFailure>
  ) {
    guard finishJob(id: id) else { return }
    switch outcome {
    case .success(let batch):
      result = batch.result
      inspection.editing.configure(result: batch.result, captures: captures, preview: batch.preview)
      failure = nil
    case .failure(let error):
      failure = error
    }
  }

  /// A reset or cancellation cannot publish old results or free the worker
  /// slot early. Request identity also rejects an unrelated completion.
  private func finishJob(id: UUID) -> Bool {
    guard let job = activeJob, job.id == id else { return false }
    activeJob = nil
    operation = nil
    isCancelling = false
    guard !job.token.isCancelled else {
      if !job.wasReset { failure = job.previousFailure }
      return false
    }
    return true
  }

  private func invalidateReconstruction() {
    inspection.close()
    result = nil
    inspection.editing.reset()
    failure = nil
    orderConfirmed = false
  }

  private func ownedRasterBytes() throws -> Int {
    // Include one bounded CGImage display copy for each visible preview.
    let inputBytes = try sumBytes(captures.map(\.image))
    let thumbnailBytes = try sumBytes(Array(thumbnails.values))
    let resultBytes = result?.image.pixels.count ?? 0
    let previewBytes = resultPreview?.pixels.count ?? 0
    return try checkedSum([inputBytes, thumbnailBytes, thumbnailBytes, resultBytes, previewBytes, previewBytes])
  }

  private func validateReconstructionBudget() throws {
    let inputBytes = try sumBytes(captures.map(\.image))
    let thumbnailsBytes = try sumBytes(Array(thumbnails.values))
    // The output cannot exceed the sum of the supplied vertical image areas.
    // Reserve it before asking the engine to allocate it, plus a bounded preview.
    let previewBytes = min(inputBytes, NativeRasterPreview.maximumResultPixels * 4)
    let reserved = try checkedSum([inputBytes, inputBytes, thumbnailsBytes, thumbnailsBytes, previewBytes, previewBytes])
    guard reserved <= limits.maximumRetainedRasterBytes else {
      throw NativeWorkspaceFailure.reconstruction(
        .resourceLimitExceeded(reason: "input, worst-case output, and display preview exceed the workspace raster budget")
      )
    }
  }

  private func sumBytes(_ images: [RasterImage]) throws -> Int {
    try checkedSum(images.map { $0.pixels.count })
  }

  private func checkedSum(_ values: [Int]) throws -> Int {
    var total = 0
    for value in values {
      let (next, overflow) = total.addingReportingOverflow(value)
      guard !overflow, value >= 0 else {
        throw NativeWorkspaceFailure.reconstruction(.outputDimensionsOverflow)
      }
      total = next
    }
    return total
  }
}
