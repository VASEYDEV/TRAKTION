#if canImport(SwiftUI)
import SwiftUI

/// Unpolished shell placeholder (prompt 00 explicitly defers visual design).
/// Canvas, sequence rail, and joint inspector arrive with prompts/03_APP_SHELL.md.
public struct CanvasPlaceholderView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("TRAKTION")
                .font(.title)
            Text("Reconstruction canvas placeholder — engine foundation stage.")
            Text("Use the traktion-lab CLI for reconstruction diagnostics.")
                .font(.caption)
        }
        .padding(40)
        .frame(minWidth: 480, minHeight: 320)
    }
}
#endif
