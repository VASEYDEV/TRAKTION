import Dispatch
import Foundation
import Observation
import TraktionDomain
import TraktionVision

public enum NativeWorkspaceOperation: Equatable, Sendable {
  case importing
  case reconstructing
}

@MainActor
@Observable
public final class NativeWorkspaceModel {
  public private(set) var captures: [CaptureAsset] = []
  public private(set) var thumbnails: [CaptureID: RasterImage] = [:]
  public private(set) var result: ReconstructionResult?
  public private(set) var resultPreview: RasterImage?
  public private(set) var failure: NativeWorkspaceFailure?
  public private(set) var operation: NativeWorkspaceOperation?
  public private(set) var isCancelling = false
  public private(set) var orderConfirmed = false

  @ObservationIgnored private let worker: any NativeWorkspaceWorking
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
    limits: PNGImportLimits = PNGImportLimits()
  ) {
    self.worker = worker ?? NativeWorkspaceWorker(limits: limits)
    self.limits = limits
  }

  public var isBusy: Bool { operation != nil }

  public var canReconstruct: Bool {
    !isBusy && orderConfirmed && (2...10).contains(captures.count) && result == nil
  }

  public var statusMessage: String {
    if isCancelling {
      return "Cancelling. Waiting for image work to finish before another operation."
    }
    switch operation {
    case .importing: return "Reading and validating PNG captures…"
    case .reconstructing: return "Reconstructing on this device…"
    case nil:
      if result != nil { return "Reconstruction complete. Original files are unchanged." }
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
    let retainedBytes: Int
    do {
      retainedBytes = try ownedRasterBytes()
    } catch {
      failure = .importFailure(.resourceLimitExceeded("The current workspace is too large. Reset it before importing another batch."))
      return
    }
    let rasterBudget = limits.maximumRetainedRasterBytes
    let job = begin(.importing)
    let worker = self.worker
    queue.async { [weak self] in
      let outcome: Result<ImportedBatch, NativeWorkspaceFailure>
      do {
        let assets = try worker.importCaptures(
          from: urls, retainedRasterBytes: retainedBytes,
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

  public func cancel() {
    guard let job = activeJob else { return }
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
      resultPreview = batch.preview
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
    result = nil
    resultPreview = nil
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
