import TraktionDomain

#if canImport(SwiftUI)
  import SwiftUI

  public struct TraktionWorkspaceView: View {
    private let workflow = [
      "Import PNG captures",
      "Confirm supplied order",
      "Reconstruct locally",
      "Inspect uncertain joints",
      "Export a new image",
    ]

    public init() {}

    public var body: some View {
      NavigationStack {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 6) {
            Text("TRAKTION")
              .font(.largeTitle.weight(.bold))
            Text("Deterministic screenshot reconstruction")
              .foregroundStyle(.secondary)
          }

          Picker("Axis", selection: .constant(ReconstructionAxis.vertical)) {
            Text("Vertical").tag(ReconstructionAxis.vertical)
            Text("Horizontal — later milestone")
              .tag(ReconstructionAxis.horizontal)
              .disabled(true)
          }
          .pickerStyle(.segmented)

          GroupBox("Foundation workflow") {
            VStack(alignment: .leading, spacing: 12) {
              ForEach(Array(workflow.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline) {
                  Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                  Text(step)
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
          }

          Text(
            "The native shell is intentionally read-only while TraktionLab establishes the golden reconstruction baseline."
          )
          .font(.callout)
          .foregroundStyle(.secondary)

          Spacer()
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
      }
    }
  }
#else
  public enum TraktionUIAvailability {
    public static let isAvailable = false
  }
#endif
