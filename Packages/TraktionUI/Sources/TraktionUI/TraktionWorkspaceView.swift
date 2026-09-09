import TraktionDomain

#if canImport(SwiftUI)
  import Foundation
  import SwiftUI
  import UniformTypeIdentifiers

  @MainActor
  public struct TraktionWorkspaceView: View {
    @State private var model: NativeWorkspaceModel
    @State private var isImportPresented = false

    public init(model: NativeWorkspaceModel = NativeWorkspaceModel()) {
      _model = State(initialValue: model)
    }

    public var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            heading
            importControls
            operationStatus

            if let message = model.failureMessage {
              GroupBox("Could not complete this step") {
                VStack(alignment: .leading, spacing: 12) {
                  Text(message)
                    .accessibilityIdentifier("workspace.failure")
                  Button("Dismiss") { model.dismissFailure() }
                    .accessibilityIdentifier("workspace.failure.dismiss")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
              }
            }

            if !model.captures.isEmpty {
              captureSequence
              reconstructionControls
            }

            if let result = model.result, let preview = model.resultPreview {
              reconstructionResult(result, preview: preview)
            }
          }
          .padding(24)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("workspace.scroll")
        #if os(macOS)
          .frame(minWidth: 520, minHeight: 420)
        #endif
      }
      .fileImporter(
        isPresented: $isImportPresented,
        allowedContentTypes: [.png],
        allowsMultipleSelection: true,
        onCompletion: { selection in
          switch selection {
          case .success(let urls):
            if !urls.isEmpty { model.importCaptures(from: urls) }
          case .failure(let error):
            let cocoaError = error as NSError
            if cocoaError.domain != NSCocoaErrorDomain || cocoaError.code != NSUserCancelledError {
              model.reportPickerFailure(error.localizedDescription)
            }
          }
        },
        onCancellation: {
          // Dismissing Files must leave the current workspace and worker untouched.
        }
      )
    }

    private var heading: some View {
      VStack(alignment: .leading, spacing: 6) {
        Text("TRAKTION")
          .font(.largeTitle.weight(.bold))
          .accessibilityIdentifier("workspace.title")
        Text("Reconstruct overlapping screenshots")
          .foregroundStyle(.secondary)
        Text("Choose 2–10 PNG captures of the same width. Arrange them from top to bottom.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }

    private var importControls: some View {
      VStack(alignment: .leading, spacing: 12) {
        Button(model.captures.isEmpty ? "Import PNG captures" : "Replace PNG captures") {
          isImportPresented = true
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.isBusy)
        .accessibilityIdentifier("workspace.import")

        if !model.captures.isEmpty || model.isBusy {
          Button("Reset workspace") { model.reset() }
            .accessibilityHint("Clears this workspace. Your original files are unchanged.")
            .accessibilityIdentifier("workspace.reset")
        }
      }
    }

    private var operationStatus: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text(model.statusMessage)
          .font(.callout)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("workspace.status")
        if model.isBusy {
          ProgressView()
            .accessibilityLabel(model.statusMessage)
          Button(model.isCancelling ? "Cancelling…" : "Cancel") { model.cancel() }
            .disabled(model.isCancelling)
            .accessibilityIdentifier("workspace.cancel")
        }
      }
    }

    private var captureSequence: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("Top-to-bottom order")
          .font(.headline)
        ForEach(Array(model.captures.enumerated()), id: \.element.id) { index, capture in
          captureCard(capture, index: index)
        }
      }
    }

    private func captureCard(_ capture: CaptureAsset, index: Int) -> some View {
      GroupBox {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top, spacing: 12) {
            if let thumbnail = model.thumbnails[capture.id] {
              WorkspaceRasterPreview(raster: thumbnail, label: "Capture thumbnail")
                .frame(width: 56, height: 80)
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
              Text("\(index + 1). \(capture.sourceName)")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("capture.\(index).name")
              Text("\(capture.image.width) × \(capture.image.height) pixels")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("capture.\(index).dimensions")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          HStack(spacing: 16) {
            Button {
              model.moveCapture(id: capture.id, offset: -1)
            } label: {
              Image(systemName: "arrow.up")
                .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(model.isBusy || index == 0)
            .accessibilityLabel("Move \(capture.sourceName) up")
            .accessibilityIdentifier("capture.\(index).moveUp")

            Button {
              model.moveCapture(id: capture.id, offset: 1)
            } label: {
              Image(systemName: "arrow.down")
                .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(model.isBusy || index == model.captures.count - 1)
            .accessibilityLabel("Move \(capture.sourceName) down")
            .accessibilityIdentifier("capture.\(index).moveDown")

            Spacer(minLength: 0)
            Button {
              model.removeCapture(id: capture.id)
            } label: {
              Image(systemName: "minus.circle")
                .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(model.isBusy)
            .accessibilityLabel("Remove \(capture.sourceName) from workspace")
            .accessibilityHint("Your original file is unchanged.")
            .accessibilityIdentifier("capture.\(index).remove")
          }
          .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }

    private var reconstructionControls: some View {
      VStack(alignment: .leading, spacing: 12) {
        Button(model.orderConfirmed ? "Order confirmed" : "Confirm top-to-bottom order") {
          model.confirmOrder()
        }
        .disabled(model.isBusy || model.orderConfirmed || model.captures.count < 2)
        .accessibilityIdentifier("workspace.order.confirm")
        Button("Reconstruct locally") { model.reconstruct() }
          .buttonStyle(.borderedProminent)
          .disabled(!model.canReconstruct)
          .accessibilityIdentifier("workspace.reconstruct")
      }
    }

    private func reconstructionResult(
      _ result: ReconstructionResult, preview: RasterImage
    ) -> some View {
      GroupBox("Preview") {
        VStack(alignment: .leading, spacing: 12) {
          Text("\(result.image.width) × \(result.image.height) pixels")
            .font(.headline)
            .accessibilityIdentifier("workspace.result.dimensions")
          WorkspaceRasterPreview(raster: preview, label: "Reconstruction preview")
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 420)
            .accessibilityIdentifier("workspace.result.preview")
          Text("Preview scaled to fit. Original captures are unchanged.")
            .font(.caption)
            .foregroundStyle(.secondary)
          ForEach(Array(result.plan.joints.enumerated()), id: \.offset) { index, joint in
            Text("Joint \(index + 1): \(joint.confidence.rawValue.capitalized)")
              .font(.callout)
              .accessibilityIdentifier("workspace.result.joint.\(index)")
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
#else
  public enum TraktionUIAvailability {
    public static let isAvailable = false
  }
#endif
