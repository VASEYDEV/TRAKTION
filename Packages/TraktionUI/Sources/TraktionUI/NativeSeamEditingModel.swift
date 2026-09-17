import Dispatch
import Foundation
import Observation
import TraktionCore
import TraktionDomain

protocol SeamPreviewRendering: Sendable {
  func render(plan: ReconstructionPlan, captures: [CaptureAsset], isCancelled: @Sendable () -> Bool) throws -> RasterImage
}

struct SeamPreviewRenderer: SeamPreviewRendering {
  func render(plan: ReconstructionPlan, captures: [CaptureAsset], isCancelled: @Sendable () -> Bool) throws -> RasterImage {
    let renderer = try PlannedRasterRenderer(plan: plan, captures: captures)
    let dimensionScale = Double(max(plan.outputWidth, plan.outputHeight)) / Double(NativeRasterPreview.maximumResultDimension)
    let pixelScale = sqrt(Double(plan.outputWidth) * Double(plan.outputHeight) / Double(NativeRasterPreview.maximumResultPixels))
    let divisor = max(1, Int(ceil(max(dimensionScale, pixelScale))))
    return try renderer.renderPreview(width: max(1, plan.outputWidth / divisor),
      height: max(1, plan.outputHeight / divisor), isCancelled: isCancelled)
  }
}

/// Workspace-owned edit session. Closing inspection cancels a draft, never committed history.
@MainActor
@Observable
final class NativeSeamEditingModel {
  // Existing viewport reserve plus old/new bounded workspace-preview transition.
  static let reservedBytes = InspectionViewport.reservedBytes + NativeRasterPreview.maximumResultPixels * 8
  private(set) var document: SeamEditingDocument?
  private(set) var draft: SeamAdjustment?
  private(set) var draftJointIndex: Int?
  private(set) var preview: RasterImage?
  private(set) var isRendering = false
  private(set) var failure: String?
  private(set) var isAdmitted = false
  @ObservationIgnored var onPlanChange: (() -> Void)?
  @ObservationIgnored private var captures: [CaptureAsset] = []
  @ObservationIgnored private let renderer: any SeamPreviewRendering
  @ObservationIgnored private let queue = DispatchQueue(label: "dev.vasey.traktion.seam-preview", qos: .userInitiated)
  @ObservationIgnored private var generation = UUID()
  @ObservationIgnored private var token: NativeWorkspaceCancellation?

  init(renderer: any SeamPreviewRendering = SeamPreviewRenderer()) { self.renderer = renderer }

  var plan: ReconstructionPlan? {
    guard let document else { return nil }
    if let draft { return try? document.preview(draft) }
    return document.plan
  }
  var isModified: Bool { document?.isModified ?? false }
  var canUndo: Bool { draft == nil && !isRendering && document?.canUndo == true }
  var canRedo: Bool { draft == nil && !isRendering && document?.canRedo == true }
  var allowedRange: ClosedRange<Int>? {
    guard let index = draftJointIndex else { return nil }
    return try? document?.allowedRange(for: index)
  }

  func configure(result: ReconstructionResult, captures: [CaptureAsset], preview: RasterImage) {
    reset()
    self.preview = preview
    self.captures = captures
    do { document = try SeamEditingDocument(plan: result.plan, captures: captures) }
    catch { failure = "This reconstruction does not support seam adjustment. Its original result is unchanged." }
  }

  func admit(retainedBytes: Int, budget: Int) {
    isAdmitted = retainedBytes >= 0 && budget >= Self.reservedBytes && retainedBytes <= budget - Self.reservedBytes
  }

  func begin(joint index: Int) {
    guard !isRendering, isAdmitted, let document, document.plan.joints.indices.contains(index) else { return }
    do {
      _ = try document.allowedRange(for: index)
      let joint = document.plan.joints[index]
      draft = SeamAdjustment(precedingCaptureID: joint.precedingCaptureID,
        followingCaptureID: joint.followingCaptureID, seamRowInOverlap: joint.seamRowInOverlap)
      draftJointIndex = index
      failure = nil
      onPlanChange?()
    } catch { failure = "This joint cannot be adjusted within its proven overlap." }
  }

  func setSeam(_ row: Int) {
    guard !isRendering, let old = draft, let document else { return }
    let next = SeamAdjustment(precedingCaptureID: old.precedingCaptureID,
      followingCaptureID: old.followingCaptureID, seamRowInOverlap: row)
    do {
      _ = try document.preview(next)
      draft = next
      failure = nil
      onPlanChange?()
    } catch { failure = "The seam must stay inside the proven overlap and between adjacent joints." }
  }

  func nudge(_ delta: Int) {
    guard let row = draft?.seamRowInOverlap else { return }
    let (next, overflow) = row.addingReportingOverflow(delta)
    guard !overflow else { return }
    setSeam(next)
  }

  func cancelDraft() {
    if draft != nil {
      generation = UUID()
      token?.cancel()
      draft = nil; draftJointIndex = nil
      failure = nil
      onPlanChange?()
    }
  }

  func apply() {
    guard !isRendering, let draft, var next = document else { return }
    do {
      try next.apply(draft)
      if next.plan == document?.plan { cancelDraft(); return }
      publish(next)
    } catch { failure = "This seam adjustment is invalid. The committed result is unchanged." }
  }

  func undo() {
    guard canUndo, var next = document else { return }
    next.undo(); publish(next)
  }

  func redo() {
    guard canRedo, var next = document else { return }
    next.redo(); publish(next)
  }

  func cancelRendering() {
    generation = UUID()
    token?.cancel()
  }

  func reset() {
    generation = UUID()
    token?.cancel()
    document = nil; draft = nil; draftJointIndex = nil; preview = nil
    captures = []; failure = nil; isAdmitted = false
    onPlanChange?()
  }

  private func publish(_ next: SeamEditingDocument) {
    guard isAdmitted, !isRendering else { return }
    let id = UUID()
    generation = id
    let token = NativeWorkspaceCancellation()
    self.token = token
    isRendering = true
    failure = nil
    let captures = self.captures
    let renderer = self.renderer
    queue.async { [weak self] in
      let outcome = Result { try renderer.render(plan: next.plan, captures: captures, isCancelled: { token.isCancelled }) }
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.isRendering = false
        self.token = nil
        guard self.generation == id, !token.isCancelled else { return }
        switch outcome {
        case .success(let preview):
          self.document = next
          self.preview = preview
          self.draft = nil
          self.draftJointIndex = nil
          self.onPlanChange?()
        case .failure:
          self.failure = "The adjusted preview could not be rendered. The committed result and history are unchanged."
        }
      }
    }
  }
}
